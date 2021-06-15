// SPDX-License-Identifier: Unlicense

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";

import "../interfaces/IVault.sol";
import "hardhat/console.sol";

/**
 * @title   Alpha Vault
 * @notice  A vault that provides liquidity on Uniswap V3.
 */
//mike mainnet 0x55535C4C56F6Bf373E06C43E44C0356aaFD0d21A
contract AlphaVault is IVault, IUniswapV3MintCallback, ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event Deposit(
        address indexed sender,
        address indexed to,
        uint256 shares,
        uint256 amount0,
        uint256 amount1
    );

    event Withdraw(
        address indexed sender,
        address indexed to,
        uint256 shares,
        uint256 amount0,
        uint256 amount1
    );

    event CollectFees(
        uint256 feesFromPool0,
        uint256 feesFromPool1,
        uint256 feesToProtocol0,
        uint256 feesToProtocol1
    );

    event Snapshot(int24 tick, uint256 totalAmount0, uint256 totalAmount1, uint256 totalSupply);

    IUniswapV3Pool public pool;
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    int24 public immutable tickSpacing;

    uint256 public protocolFee;
    uint256 public maxTotalSupply;
    address public strategy;
    address public governance;
    address public pendingGovernance;
    bool public finalized;

    int24 public baseLower;
    int24 public baseUpper;
    int24 public limitLower;
    int24 public limitUpper;
    uint256 public accruedProtocolFees0;
    uint256 public accruedProtocolFees1;

    /**
     * @dev After deploying, strategy needs to be set via `setStrategy()`
     * @param _pool Underlying Uniswap V3 pool
     * @param _protocolFee Protocol fee expressed as multiple of 1e-6
     * @param _maxTotalSupply Pause deposits if total supply exceeds this
     */
    //mike 先deploy，然后单独设置strategy
    constructor(
        address _pool,//mike uniswap v3池子
        uint256 _protocolFee,//mike 本协议的使用费
        uint256 _maxTotalSupply
    ) ERC20("Alpha Vault", "AV") {
        pool = IUniswapV3Pool(_pool);//mike 设置uni池子
        token0 = IERC20(pool.token0());//mike 设置uni池子的token0
        token1 = IERC20(pool.token1());//mike 设置uni池子的token1
        tickSpacing = pool.tickSpacing();

        protocolFee = _protocolFee;//mike 设置费用
        maxTotalSupply = _maxTotalSupply;//mike 设置最大supply
        governance = msg.sender;//mike 设置governance

        require(_protocolFee < 1e6, "protocolFee");
    }

    /**
     * @notice Deposits tokens in proportion to the vault's current holdings.
     * @dev These tokens sit in the vault and are not used for liquidity on
     * Uniswap until the next rebalance. Also note it's not necessary to check
     * if user manipulated price to deposit cheaper, as the value of range
     * orders can only by manipulated higher.
     * @param amount0Desired Max amount of token0 to deposit
     * @param amount1Desired Max amount of token1 to deposit
     * @param amount0Min Revert if resulting `amount0` is less than this
     * @param amount1Min Revert if resulting `amount1` is less than this
     * @param to Recipient of shares
     * @return shares Number of shares minted
     * @return amount0 Amount of token0 deposited
     * @return amount1 Amount of token1 deposited
     */
    //mike 用户deposit，这里还没有将流动性添加到univ3
    function deposit(
        uint256 amount0Desired,//mike 最大存的值
        uint256 amount1Desired,//mike 最大存的值
        uint256 amount0Min,//mike 最小收到的值
        uint256 amount1Min,//mike 最小收到的值
        address to//mike shares给到to
    )
        external
        override
        nonReentrant
        returns (
            uint256 shares,
            uint256 amount0,
            uint256 amount1
        )
    {
        require(amount0Desired > 0 || amount1Desired > 0, "amount0Desired or amount1Desired");
        require(to != address(0) && to != address(this), "to");

        // Do zero-burns to poke the Uniswap pools so earned fees are updated
        //mike 检查，如果区间有流动性，就burn掉
        if (_positionLiquidity(baseLower, baseUpper) > 0) {
            pool.burn(baseLower, baseUpper, 0);
        }
        if (_positionLiquidity(limitLower, limitUpper) > 0) {
            pool.burn(limitLower, limitUpper, 0);
        }
        //mike 计算shares，仅仅是计算
        (shares, amount0, amount1) = _calcSharesAndAmounts(amount0Desired, amount1Desired);
        require(shares > 0, "shares");
        require(amount0 >= amount0Min, "amount0Min");
        require(amount1 >= amount1Min, "amount1Min");

        // Pull in tokens from sender
        //mike 上面通过的话，就将amount0和amount1转到本vault
        if (amount0 > 0) token0.safeTransferFrom(msg.sender, address(this), amount0);
        if (amount1 > 0) token1.safeTransferFrom(msg.sender, address(this), amount1);
        
        // Mint shares to recipient
        //mike mint shares给to
        _mint(to, shares);
        emit Deposit(msg.sender, to, shares, amount0, amount1);
        require(totalSupply() <= maxTotalSupply, "maxTotalSupply");
    }

    // @dev Calculates the largest possible `amount0` and `amount1` such that
    // they're in the same proportion as total amounts, but not greater than
    // `amount0Desired` and `amount1Desired` respectively.
    //mike 计算可以获取到的shares、amount0、amount1
    function _calcSharesAndAmounts(uint256 amount0Desired, uint256 amount1Desired)
        internal
        view
        returns (
            uint256 shares,
            uint256 amount0,
            uint256 amount1
        )
    {
        uint256 totalSupply = totalSupply();
        (uint256 total0, uint256 total1) = getTotalAmounts();

        // If total supply > 0, vault can't be empty
        assert(totalSupply == 0 || total0 > 0 || total1 > 0);

        if (totalSupply == 0) {//mike vault第一次有人deposit
            // For first deposit, just use the amounts desired
            amount0 = amount0Desired;
            amount1 = amount1Desired;
            shares = Math.max(amount0, amount1);
        } else if (total0 == 0) {//mike token0没有流动性，那就只depisit token1
            amount1 = amount1Desired;
            shares = amount1.mul(totalSupply).div(total1);
        } else if (total1 == 0) {//mike token1没有流动性，那就只depisit token0
            amount0 = amount0Desired;
            shares = amount0.mul(totalSupply).div(total0);
        } else {
            //mike 找较小的，然后计算shares
            uint256 cross = Math.min(amount0Desired.mul(total1), amount1Desired.mul(total0));
            require(cross > 0, "cross");

            // Round up amounts
            amount0 = cross.sub(1).div(total1).add(1);
            amount1 = cross.sub(1).div(total0).add(1);
            shares = cross.mul(totalSupply).div(total0).div(total1);
        }
    }

    /**
     * @notice Withdraws tokens in proportion to the vault's holdings.
     * @dev Removes proportional amount of liquidity from Uniswap. Note it
     * doesn't collect share of fees since last rebalance to save gas.
     * @param shares Shares burned by sender
     * @param amount0Min Revert if resulting `amount0` is smaller than this
     * @param amount1Min Revert if resulting `amount1` is smaller than this
     * @param to Recipient of tokens
     * @return amount0 Amount of token0 sent to recipient
     * @return amount1 Amount of token1 sent to recipient
     */
    function withdraw(
        uint256 shares,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) external override nonReentrant returns (uint256 amount0, uint256 amount1) {
        require(shares > 0, "shares");
        require(to != address(0) && to != address(this), "to");

        // Withdraw proportion of liquidity from Uniswap pool and push
        // resulting tokens to recipient directly
        //mike 移除base里的流动性
        (uint256 baseAmount0, uint256 baseAmount1) =
            _burnLiquidityShare(baseLower, baseUpper, shares, to);
        //mike 移除limit里的流动性
        (uint256 limitAmount0, uint256 limitAmount1) =
            _burnLiquidityShare(limitLower, limitUpper, shares, to);

        // Push tokens proportional to unused balances
        uint256 totalSupply = totalSupply();
        uint256 unusedAmount0 = _balance0().mul(shares).div(totalSupply);
        uint256 unusedAmount1 = _balance1().mul(shares).div(totalSupply);
        if (unusedAmount0 > 0) token0.safeTransfer(to, unusedAmount0);
        if (unusedAmount1 > 0) token1.safeTransfer(to, unusedAmount1);

        // Sum up total amounts sent to recipient
        amount0 = baseAmount0.add(limitAmount0).add(unusedAmount0);
        amount1 = baseAmount1.add(limitAmount1).add(unusedAmount1);
        require(amount0 >= amount0Min, "amount0Min");
        require(amount1 >= amount1Min, "amount1Min");

        // Burn shares
        _burn(msg.sender, shares);//mike burn掉shares
        emit Withdraw(msg.sender, to, shares, amount0, amount1);
    }

    /// @dev Withdraws share of liquidity in a range from Uniswap pool. Doesn't
    /// collect earned fees. Reverts if total supply is 0.
    //mike 根据shares移除流动性
    function _burnLiquidityShare(
        int24 tickLower,
        int24 tickUpper,
        uint256 shares,
        address to
    ) internal returns (uint256 amount0, uint256 amount1) {
        uint128 position = _positionLiquidity(tickLower, tickUpper);
        uint256 liquidity = uint256(position).mul(shares).div(totalSupply());

        if (liquidity > 0) {
            (amount0, amount1) = pool.burn(tickLower, tickUpper, _toUint128(liquidity));//mike 移除流动性

            if (amount0 > 0 || amount1 > 0) {
                //mike collect收益
                (amount0, amount1) = pool.collect(
                    to,
                    tickLower,
                    tickUpper,
                    _toUint128(amount0),
                    _toUint128(amount1)
                );
            }
        }
    }

    /**
     * @notice Updates vault's positions. Can only be called by the strategy.
     * @dev Two orders are placed - a base order and a limit order. The base
     * order is placed first with as much liquidity as possible. This order
     * should use up all of one token, leaving only the other one. This excess
     * amount is then placed as a single-sided bid or ask order.
     */
    //mike 由strategy发起调用，调整流动性区间，发起base order和limit order到uniswapv3
    function rebalance(
        int24 _baseLower,
        int24 _baseUpper,
        int24 _bidLower,
        int24 _bidUpper,
        int24 _askLower,
        int24 _askUpper
    ) external nonReentrant {
        require(msg.sender == strategy, "strategy");
        _checkRange(_baseLower, _baseUpper);
        _checkRange(_bidLower, _bidUpper);
        _checkRange(_askLower, _askUpper);

        (, int24 tick, , , , , ) = pool.slot0();
        require(_bidUpper <= tick, "bidUpper");
        require(_askLower > tick, "askLower"); // inequality is strict as tick is rounded down

        // Withdraw all current liquidity from Uniswap pool
        _burnAllLiquidity(baseLower, baseUpper);//mike 将现有的univ3 base流动性remove掉
        _burnAllLiquidity(limitLower, limitUpper);//mike 将现有的univ3 limit流动性remove掉

        // Emit snapshot to record balances and supply
        uint256 balance0 = _balance0();//mike 看有多少token0
        uint256 balance1 = _balance1();//mike 看有多少token1
        emit Snapshot(tick, balance0, balance1, totalSupply());

        // Place base order on Uniswap
        //mike 创建base order
        uint128 liquidity = _liquidityForAmounts(_baseLower, _baseUpper, balance0, balance1);//mike 计算可用的流动性
        _mintLiquidity(_baseLower, _baseUpper, liquidity);
        (baseLower, baseUpper) = (_baseLower, _baseUpper);//mike 记录tick区间

        balance0 = _balance0();//mike 看还剩多少token0
        balance1 = _balance1();//mike 看还剩多少token1

        // Place bid or ask order on Uniswap depending on which token is left
        //mike 只读方式获取bid和ask的流动性大小
        uint128 bidLiquidity = _liquidityForAmounts(_bidLower, _bidUpper, balance0, balance1);
        uint128 askLiquidity = _liquidityForAmounts(_askLower, _askUpper, balance0, balance1);
        if (bidLiquidity > askLiquidity) {//mike 如果bid流动性大，就添加bid流动性
            _mintLiquidity(_bidLower, _bidUpper, bidLiquidity);
            (limitLower, limitUpper) = (_bidLower, _bidUpper);//mike 记录tick区间
        } else {//mike 如果ask流动性大，就添加ask流动性
            _mintLiquidity(_askLower, _askUpper, askLiquidity);
            (limitLower, limitUpper) = (_askLower, _askUpper);//mike 记录tick区间
        }
    }
    //mike 检查参数
    function _checkRange(int24 tickLower, int24 tickUpper) internal view {
        int24 _tickSpacing = tickSpacing;
        require(tickLower < tickUpper, "tickLower < tickUpper");
        require(tickLower >= TickMath.MIN_TICK, "tickLower too low");
        require(tickUpper <= TickMath.MAX_TICK, "tickUpper too high");
        require(tickLower % _tickSpacing == 0, "tickLower % tickSpacing");
        require(tickUpper % _tickSpacing == 0, "tickUpper % tickSpacing");
    }

    /// @dev Withdraws all liquidity in a range from Uniswap pool and collects
    /// all fees in the process.
    //mike burn掉范围内的所有流动性
    function _burnAllLiquidity(int24 tickLower, int24 tickUpper) internal {
        // Burn all liquidity in this range
        uint256 owed0 = 0;
        uint256 owed1 = 0;
        uint128 liquidity = _positionLiquidity(tickLower, tickUpper);//mike 获取该区间的流动性
        if (liquidity > 0) {
            (owed0, owed1) = pool.burn(tickLower, tickUpper, liquidity);
        }

        // Collect all owed tokens including earned fees
        //mike 取回做市的资产+赚取的费用
        (uint256 collect0, uint256 collect1) =
            pool.collect(
                address(this),
                tickLower,
                tickUpper,
                type(uint128).max,
                type(uint128).max
            );

        uint256 feesFromPool0 = collect0.sub(owed0);//mike 赚的钱
        uint256 feesFromPool1 = collect1.sub(owed1);//mike 赚的钱
        uint256 feesToProtocol0 = 0;
        uint256 feesToProtocol1 = 0;

        // Update accrued protocol fees
        uint256 _protocolFee = protocolFee;
        if (_protocolFee > 0) {
            feesToProtocol0 = feesFromPool0.mul(_protocolFee).div(1e6);//mike 本vault抽取手续费
            feesToProtocol1 = feesFromPool1.mul(_protocolFee).div(1e6);//mike 本vault抽取手续费
            accruedProtocolFees0 = accruedProtocolFees0.add(feesToProtocol0);//mike 累计起来
            accruedProtocolFees1 = accruedProtocolFees1.add(feesToProtocol1);//mike 累计起来
        }
        emit CollectFees(feesFromPool0, feesFromPool1, feesToProtocol0, feesToProtocol1);
    }

    /// @dev Deposits liquidity in a range on the Uniswap pool.
    //mike mint流动性，其实就是向univ3添加流动性，发送给univ3去mint到本合约
    function _mintLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal {
        if (liquidity > 0) {
            pool.mint(address(this), tickLower, tickUpper, liquidity, "");
        }
    }

    /**
     * @notice Calculates the vault's total holdings of token0 and token1 - in
     * other words, how much of each token the vault would hold if it withdrew
     * all its liquidity from Uniswap.
     */
    //mike 获取总的total0、total1 amount
    function getTotalAmounts() public view override returns (uint256 total0, uint256 total1) {
        (uint256 baseAmount0, uint256 baseAmount1) = _positionAmounts(baseLower, baseUpper);
        (uint256 limitAmount0, uint256 limitAmount1) = _positionAmounts(limitLower, limitUpper);
        total0 = _balance0().add(baseAmount0).add(limitAmount0);
        total1 = _balance1().add(baseAmount1).add(limitAmount1);
    }

    /// @dev Amount of token0 held as unused balance.
    //mike balance需要减去使用费
    function _balance0() internal view returns (uint256) {
        return token0.balanceOf(address(this)).sub(accruedProtocolFees0);
    }

    /// @dev Amount of token1 held as unused balance.
    //mike balance需要减去使用费
    function _balance1() internal view returns (uint256) {
        return token1.balanceOf(address(this)).sub(accruedProtocolFees1);
    }

    /// @dev Amount of liquidity in vault's position.
    //mike 只读计算流动性
    function _positionLiquidity(int24 tickLower, int24 tickUpper)
        internal
        view
        returns (uint128 liquidity)
    {
        //mike 根据lower和upper计算positionkey
        bytes32 positionKey = PositionKey.compute(address(this), tickLower, tickUpper);
        (liquidity, , , , ) = pool.positions(positionKey);//mike 获取这个区间的流动性
    }

    /// @dev Amounts of token0 and token1 held in vault's position.
    //mike 计算补偿后的amounts
    function _positionAmounts(int24 tickLower, int24 tickUpper)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        bytes32 positionKey = PositionKey.compute(address(this), tickLower, tickUpper);
        (uint128 liquidity, , , uint128 tokensOwed0, uint128 tokensOwed1) =
            pool.positions(positionKey);

        (amount0, amount1) = _amountsForLiquidity(tickLower, tickUpper, liquidity);
        amount0 = amount0.add(uint256(tokensOwed0));
        amount1 = amount1.add(uint256(tokensOwed1));
    }

    /// @dev Wrapper around `LiquidityAmounts.getAmountsForLiquidity()`.
    //mike 根据流动性获取amount
    function _amountsForLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal view returns (uint256, uint256) {
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        return
            LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );
    }

    /// @dev Wrapper around `LiquidityAmounts.getLiquidityForAmounts()`.
    //mike 根据amount获取流动性大小
    function _liquidityForAmounts(
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (uint128) {
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        return
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
    }

    /// @dev Casts uint256 to uint128 with overflow check.
    function _toUint128(uint256 x) internal pure returns (uint128) {
        assert(x <= type(uint128).max);
        return uint128(x);
    }

    /// @dev Callback for Uniswap V3 pool.
    //mike 回掉函数，转钱给调用者
    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        require(msg.sender == address(pool));
        if (amount0 > 0) token0.safeTransfer(msg.sender, amount0);
        if (amount1 > 0) token1.safeTransfer(msg.sender, amount1);
    }

    /**
     * @notice Used to collect accumulated protocol fees.
     */
    //mike 取amount0个token0，amount1个token1，这些都是协议费用
    function collectProtocol(
        uint256 amount0,
        uint256 amount1,
        address to
    ) external onlyGovernance {
        accruedProtocolFees0 = accruedProtocolFees0.sub(amount0);
        accruedProtocolFees1 = accruedProtocolFees1.sub(amount1);
        if (amount0 > 0) token0.safeTransfer(to, amount0);
        if (amount1 > 0) token1.safeTransfer(to, amount1);
    }

    /**
     * @notice Removes tokens accidentally sent to this vault.
     */
    //mike 退回因意外转来的其他token
    function sweep(
        IERC20 token,
        uint256 amount,
        address to
    ) external onlyGovernance {
        require(token != token0 && token != token1, "token");
        token.safeTransfer(to, amount);
    }

    /**
     * @notice Used to set the strategy contract that determines the position
     * ranges and calls rebalance(). Must be called after this vault is
     * deployed.
     */
    //mike 设置strategy
    function setStrategy(address _strategy) external onlyGovernance {
        strategy = _strategy;
    }

    /**
     * @notice Used to change the protocol fee charged on pool fees earned from
     * Uniswap, expressed as multiple of 1e-6.
     */
    //mike 设置协议费用
    function setProtocolFee(uint256 _protocolFee) external onlyGovernance {
        require(_protocolFee < 1e6, "protocolFee");
        protocolFee = _protocolFee;
    }

    /**
     * @notice Used to change deposit cap for a guarded launch or to ensure
     * vault doesn't grow too large relative to the pool. Cap is on total
     * supply rather than amounts of token0 and token1 as those amounts
     * fluctuate naturally over time.
     */
    //mike 控制最大供应
    function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyGovernance {
        maxTotalSupply = _maxTotalSupply;
    }

    /**
     * @notice Used to renounce emergency powers. Cannot be undone.
     */
    //mike 设置本vault废弃
    function finalize() external onlyGovernance {
        finalized = true;
    }

    /**
     * @notice Transfers tokens to governance in case of emergency. Cannot be
     * called if already finalized.
     */
    //mike withdraw token到governance
    function emergencyWithdraw(IERC20 token, uint256 amount) external onlyGovernance {
        require(!finalized, "finalized");
        token.safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Removes liquidity and transfer tokens to governance in case of
     * emergency. Cannot be called if already finalized.
     */
    //mike 紧急burn，移除v3的流动性
    function emergencyBurn(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) external onlyGovernance {
        require(!finalized, "finalized");
        pool.burn(tickLower, tickUpper, liquidity);//mike 移除流动性
        pool.collect(msg.sender, tickLower, tickUpper, type(uint128).max, type(uint128).max);//mike 取回赚取的fee，能取多少取多少
    }

    /**
     * @notice Governance address is not updated until the new governance
     * address has called `acceptGovernance()` to accept this responsibility.
     */
    //mike 设置pending
    function setGovernance(address _governance) external onlyGovernance {
        pendingGovernance = _governance;
    }

    /**
     * @notice `setGovernance()` should be called by the existing governance
     * address prior to calling this function.
     */
    //mike pendingGovernor接受
    function acceptGovernance() external {
        require(msg.sender == pendingGovernance, "pendingGovernance");
        governance = msg.sender;
    }

    modifier onlyGovernance {
        require(msg.sender == governance, "governance");
        _;
    }

    function myBalance0() public view returns (uint256) {
        return token0.balanceOf(msg.sender);
    }

    function myBalance1() public view returns (uint256) {
        return token1.balanceOf(msg.sender);
    }
}

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
    //mike ???deploy?????????????????????strategy
    constructor(
        address _pool,//mike uniswap v3??????
        uint256 _protocolFee,//mike ?????????????????????
        uint256 _maxTotalSupply
    ) ERC20("Alpha Vault", "AV") {
        pool = IUniswapV3Pool(_pool);//mike ??????uni??????
        token0 = IERC20(pool.token0());//mike ??????uni?????????token0
        token1 = IERC20(pool.token1());//mike ??????uni?????????token1
        tickSpacing = pool.tickSpacing();

        protocolFee = _protocolFee;//mike ????????????
        maxTotalSupply = _maxTotalSupply;//mike ????????????supply
        governance = msg.sender;//mike ??????governance

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
    //mike ??????deposit???????????????????????????????????????univ3
    function deposit(
        uint256 amount0Desired,//mike ???????????????
        uint256 amount1Desired,//mike ???????????????
        uint256 amount0Min,//mike ??????????????????
        uint256 amount1Min,//mike ??????????????????
        address to//mike shares??????to
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
        //mike ???????????????????????????????????????burn???
        if (_positionLiquidity(baseLower, baseUpper) > 0) {
            pool.burn(baseLower, baseUpper, 0);
        }
        if (_positionLiquidity(limitLower, limitUpper) > 0) {
            pool.burn(limitLower, limitUpper, 0);
        }
        //mike ??????shares??????????????????
        (shares, amount0, amount1) = _calcSharesAndAmounts(amount0Desired, amount1Desired);
        require(shares > 0, "shares");
        require(amount0 >= amount0Min, "amount0Min");
        require(amount1 >= amount1Min, "amount1Min");

        // Pull in tokens from sender
        //mike ???????????????????????????amount0???amount1?????????vault
        if (amount0 > 0) token0.safeTransferFrom(msg.sender, address(this), amount0);
        if (amount1 > 0) token1.safeTransferFrom(msg.sender, address(this), amount1);
        
        // Mint shares to recipient
        //mike mint shares???to
        _mint(to, shares);
        emit Deposit(msg.sender, to, shares, amount0, amount1);
        require(totalSupply() <= maxTotalSupply, "maxTotalSupply");
    }

    // @dev Calculates the largest possible `amount0` and `amount1` such that
    // they're in the same proportion as total amounts, but not greater than
    // `amount0Desired` and `amount1Desired` respectively.
    //mike ????????????????????????shares???amount0???amount1
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

        if (totalSupply == 0) {//mike vault???????????????deposit
            // For first deposit, just use the amounts desired
            amount0 = amount0Desired;
            amount1 = amount1Desired;
            shares = Math.max(amount0, amount1);
        } else if (total0 == 0) {//mike token0???????????????????????????depisit token1
            amount1 = amount1Desired;
            shares = amount1.mul(totalSupply).div(total1);
        } else if (total1 == 0) {//mike token1???????????????????????????depisit token0
            amount0 = amount0Desired;
            shares = amount0.mul(totalSupply).div(total0);
        } else {
            //mike ???????????????????????????shares
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
        //mike ??????base???????????????
        (uint256 baseAmount0, uint256 baseAmount1) =
            _burnLiquidityShare(baseLower, baseUpper, shares, to);
        //mike ??????limit???????????????
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
        _burn(msg.sender, shares);//mike burn???shares
        emit Withdraw(msg.sender, to, shares, amount0, amount1);
    }

    /// @dev Withdraws share of liquidity in a range from Uniswap pool. Doesn't
    /// collect earned fees. Reverts if total supply is 0.
    //mike ??????shares???????????????
    function _burnLiquidityShare(
        int24 tickLower,
        int24 tickUpper,
        uint256 shares,
        address to
    ) internal returns (uint256 amount0, uint256 amount1) {
        uint128 position = _positionLiquidity(tickLower, tickUpper);
        uint256 liquidity = uint256(position).mul(shares).div(totalSupply());

        if (liquidity > 0) {
            (amount0, amount1) = pool.burn(tickLower, tickUpper, _toUint128(liquidity));//mike ???????????????

            if (amount0 > 0 || amount1 > 0) {
                //mike collect??????
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
    //mike ???strategy?????????????????????????????????????????????base order???limit order???uniswapv3
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
        _burnAllLiquidity(baseLower, baseUpper);//mike ????????????univ3 base?????????remove???
        _burnAllLiquidity(limitLower, limitUpper);//mike ????????????univ3 limit?????????remove???

        // Emit snapshot to record balances and supply
        uint256 balance0 = _balance0();//mike ????????????token0
        uint256 balance1 = _balance1();//mike ????????????token1
        emit Snapshot(tick, balance0, balance1, totalSupply());

        // Place base order on Uniswap
        //mike ??????base order
        uint128 liquidity = _liquidityForAmounts(_baseLower, _baseUpper, balance0, balance1);//mike ????????????????????????
        _mintLiquidity(_baseLower, _baseUpper, liquidity);
        (baseLower, baseUpper) = (_baseLower, _baseUpper);//mike ??????tick??????

        balance0 = _balance0();//mike ???????????????token0
        balance1 = _balance1();//mike ???????????????token1

        // Place bid or ask order on Uniswap depending on which token is left
        //mike ??????????????????bid???ask??????????????????
        uint128 bidLiquidity = _liquidityForAmounts(_bidLower, _bidUpper, balance0, balance1);
        uint128 askLiquidity = _liquidityForAmounts(_askLower, _askUpper, balance0, balance1);
        if (bidLiquidity > askLiquidity) {//mike ??????bid????????????????????????bid?????????
            _mintLiquidity(_bidLower, _bidUpper, bidLiquidity);
            (limitLower, limitUpper) = (_bidLower, _bidUpper);//mike ??????tick??????
        } else {//mike ??????ask????????????????????????ask?????????
            _mintLiquidity(_askLower, _askUpper, askLiquidity);
            (limitLower, limitUpper) = (_askLower, _askUpper);//mike ??????tick??????
        }
    }
    //mike ????????????
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
    //mike burn??????????????????????????????
    function _burnAllLiquidity(int24 tickLower, int24 tickUpper) internal {
        // Burn all liquidity in this range
        uint256 owed0 = 0;
        uint256 owed1 = 0;
        uint128 liquidity = _positionLiquidity(tickLower, tickUpper);//mike ???????????????????????????
        if (liquidity > 0) {
            (owed0, owed1) = pool.burn(tickLower, tickUpper, liquidity);
        }

        // Collect all owed tokens including earned fees
        //mike ?????????????????????+???????????????
        (uint256 collect0, uint256 collect1) =
            pool.collect(
                address(this),
                tickLower,
                tickUpper,
                type(uint128).max,
                type(uint128).max
            );

        uint256 feesFromPool0 = collect0.sub(owed0);//mike ?????????
        uint256 feesFromPool1 = collect1.sub(owed1);//mike ?????????
        uint256 feesToProtocol0 = 0;
        uint256 feesToProtocol1 = 0;

        // Update accrued protocol fees
        uint256 _protocolFee = protocolFee;
        if (_protocolFee > 0) {
            feesToProtocol0 = feesFromPool0.mul(_protocolFee).div(1e6);//mike ???vault???????????????
            feesToProtocol1 = feesFromPool1.mul(_protocolFee).div(1e6);//mike ???vault???????????????
            accruedProtocolFees0 = accruedProtocolFees0.add(feesToProtocol0);//mike ????????????
            accruedProtocolFees1 = accruedProtocolFees1.add(feesToProtocol1);//mike ????????????
        }
        emit CollectFees(feesFromPool0, feesFromPool1, feesToProtocol0, feesToProtocol1);
    }

    /// @dev Deposits liquidity in a range on the Uniswap pool.
    //mike mint???????????????????????????univ3???????????????????????????univ3???mint????????????
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
    //mike ????????????total0???total1 amount
    function getTotalAmounts() public view override returns (uint256 total0, uint256 total1) {
        (uint256 baseAmount0, uint256 baseAmount1) = _positionAmounts(baseLower, baseUpper);
        (uint256 limitAmount0, uint256 limitAmount1) = _positionAmounts(limitLower, limitUpper);
        total0 = _balance0().add(baseAmount0).add(limitAmount0);
        total1 = _balance1().add(baseAmount1).add(limitAmount1);
    }

    /// @dev Amount of token0 held as unused balance.
    //mike balance?????????????????????
    function _balance0() internal view returns (uint256) {
        return token0.balanceOf(address(this)).sub(accruedProtocolFees0);
    }

    /// @dev Amount of token1 held as unused balance.
    //mike balance?????????????????????
    function _balance1() internal view returns (uint256) {
        return token1.balanceOf(address(this)).sub(accruedProtocolFees1);
    }

    /// @dev Amount of liquidity in vault's position.
    //mike ?????????????????????
    function _positionLiquidity(int24 tickLower, int24 tickUpper)
        internal
        view
        returns (uint128 liquidity)
    {
        //mike ??????lower???upper??????positionkey
        bytes32 positionKey = PositionKey.compute(address(this), tickLower, tickUpper);
        (liquidity, , , , ) = pool.positions(positionKey);//mike ??????????????????????????????
    }

    /// @dev Amounts of token0 and token1 held in vault's position.
    //mike ??????????????????amounts
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
    //mike ?????????????????????amount
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
    //mike ??????amount?????????????????????
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
    //mike ?????????????????????????????????
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
    //mike ???amount0???token0???amount1???token1???????????????????????????
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
    //mike ??????????????????????????????token
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
    //mike ??????strategy
    function setStrategy(address _strategy) external onlyGovernance {
        strategy = _strategy;
    }

    /**
     * @notice Used to change the protocol fee charged on pool fees earned from
     * Uniswap, expressed as multiple of 1e-6.
     */
    //mike ??????????????????
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
    //mike ??????????????????
    function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyGovernance {
        maxTotalSupply = _maxTotalSupply;
    }

    /**
     * @notice Used to renounce emergency powers. Cannot be undone.
     */
    //mike ?????????vault??????
    function finalize() external onlyGovernance {
        finalized = true;
    }

    /**
     * @notice Transfers tokens to governance in case of emergency. Cannot be
     * called if already finalized.
     */
    //mike withdraw token???governance
    function emergencyWithdraw(IERC20 token, uint256 amount) external onlyGovernance {
        require(!finalized, "finalized");
        token.safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Removes liquidity and transfer tokens to governance in case of
     * emergency. Cannot be called if already finalized.
     */
    //mike ??????burn?????????v3????????????
    function emergencyBurn(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) external onlyGovernance {
        require(!finalized, "finalized");
        pool.burn(tickLower, tickUpper, liquidity);//mike ???????????????
        pool.collect(msg.sender, tickLower, tickUpper, type(uint128).max, type(uint128).max);//mike ???????????????fee????????????????????????
    }

    /**
     * @notice Governance address is not updated until the new governance
     * address has called `acceptGovernance()` to accept this responsibility.
     */
    //mike ??????pending
    function setGovernance(address _governance) external onlyGovernance {
        pendingGovernance = _governance;
    }

    /**
     * @notice `setGovernance()` should be called by the existing governance
     * address prior to calling this function.
     */
    //mike pendingGovernor??????
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

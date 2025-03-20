// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

interface IVault is IERC20 {
    // returns value of one wBLT in BLT tokens
    function pricePerShare() external view returns (uint256);
}

interface IBltManager {
    // Returns AUM of BLT for calculating price.
    function getAum(bool maximise) external view returns (uint256);
}

contract wBltOracle is Ownable2Step {
    /* ========== STATE VARIABLES ========== */

    /// @notice BMX's BLT Manager, use this to pull our total AUM in BLT.
    IBltManager public immutable bltManager;

    /// @notice Address for BLT, BMX's LP token and the want token for our wBLT vault.
    IERC20 public immutable blt;

    /// @notice Address of our wBLT, a Yearn vault token.
    IVault public immutable wBlt;

    /* ========== CONSTRUCTOR ========== */

    constructor(IBltManager _bltManager, IERC20 _blt, IVault _wBlt) {
        require(address(_bltManager) != address(0), "Zero address: bltManager");
        require(address(_blt) != address(0), "Zero address: blt");
        require(address(_wBlt) != address(0), "Zero address: wBlt");
        bltManager = _bltManager;
        blt = _blt;
        wBlt = _wBlt;
    }

    /* ========== VIEWS ========== */

    /// @notice Decimals of our price
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /// @notice Gets the current price of wBLT collateral
    /// @dev Return our price using a standard Chainlink aggregator interface
    /// @return The price of wBLT
    function latestRoundData()
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (
            uint80(block.number),
            int256(getLivePrice()),
            block.timestamp,
            block.timestamp,
            uint80(block.number)
        );
    }

    /// @notice Gets the current price of wBLT collateral without any corrections
    /// @dev Pulls the total AUM in BMX's BLT, and multiplies by our vault token's share price
    function getLivePrice() public view returns (uint256) {
        // aum reported in USD with 30 decimals
        uint256 bltPrice = (bltManager.getAum(false) * 1e6) / blt.totalSupply();

        // add in vault gains
        uint256 sharePrice = wBlt.pricePerShare();

        return (bltPrice * sharePrice) / 1e18;
    }

    function renounceOwnership() public override onlyOwner {
        revert();
    }
}

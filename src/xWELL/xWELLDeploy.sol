pragma solidity 0.8.19;

import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

import {xWELL} from "@protocol/xWELL/xWELL.sol";
import {Addresses} from "@proposals/Addresses.sol";
import {XERC20Lockbox} from "@protocol/xWELL/XERC20Lockbox.sol";
import {RateLimitMidPointInfo} from "@protocol/xWELL/MintLimits.sol";

contract xWELLDeploy {
    /// @notice for base deployment
    /// @param tokenName The name of the token
    /// @param tokenSymbol The symbol of the token
    /// @param tokenOwner The owner of the token, Temporal Governor on Base, Timelock on Moonbeam
    /// @param newRateLimits The rate limits for the token
    /// @param newPauseDuration The duration of the pause
    /// @param newPauseGuardian The pause guardian address
    function deployXWell(
        string memory tokenName,
        string memory tokenSymbol,
        address tokenOwner,
        RateLimitMidPointInfo[] memory newRateLimits,
        uint128 newPauseDuration,
        address newPauseGuardian
    )
        public
        returns (address xwellLogic, address xwellImpl, address proxyAdmin)
    {
        /// deploy the ERC20 wrapper for USDBC
        xwellLogic = address(new xWELL());

        proxyAdmin = address(new ProxyAdmin());

        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,string,address,(uint112,uint128,address)[],uint128,address)",
            tokenName,
            tokenSymbol,
            tokenOwner,
            newRateLimits,
            newPauseDuration,
            newPauseGuardian
        );

        xwellImpl = address(
            new TransparentUpgradeableProxy(
                address(xwellLogic),
                address(proxyAdmin),
                initData
            )
        );

        xWELL(xwellImpl).initialize(
            tokenName,
            tokenSymbol,
            tokenOwner,
            newRateLimits,
            newPauseDuration,
            newPauseGuardian
        );
    }

    /// @notice for Moonbeam deployment
    /// @param addresses The addresses contract
    /// @param tokenName The name of the token
    /// @param tokenSymbol The symbol of the token
    /// @param tokenOwner The owner of the token, Temporal Governor on Base, Timelock on Moonbeam
    /// @param newRateLimits The rate limits for the token
    /// @param newPauseDuration The duration of the pause
    /// @param newPauseGuardian The pause guardian address
    function deployXWellAndLockBox(
        Addresses addresses,
        string memory tokenName,
        string memory tokenSymbol,
        address tokenOwner,
        RateLimitMidPointInfo[] memory newRateLimits,
        uint128 newPauseDuration,
        address newPauseGuardian
    )
        public
        returns (
            address xwellLogic,
            address xwellProxy,
            address proxyAdmin,
            address lockbox
        )
    {
        /// deploy the ERC20 wrapper for USDBC
        xwellLogic = address(new xWELL());

        proxyAdmin = address(new ProxyAdmin());

        /// do not initialize the proxy, that is the final step
        xwellProxy = address(
            new TransparentUpgradeableProxy(
                address(xwellLogic),
                address(proxyAdmin),
                ""
            )
        );

        lockbox = deployLockBox(
            xwellProxy, /// proxy is actually the xWELL token contract
            addresses.getAddress("WELL")
        );

        RateLimitMidPointInfo[]
            memory _newRateLimits = new RateLimitMidPointInfo[](
                newRateLimits.length + 1
            );
        for (uint256 i = 0; i < newRateLimits.length; i++) {
            _newRateLimits[i] = newRateLimits[i];
        }

        _newRateLimits[_newRateLimits.length - 1] = RateLimitMidPointInfo({
            bufferCap: type(uint112).max, /// max buffer cap, lock box can infinite mint up to max supply
            rateLimitPerSecond: 0, /// no rate limit
            rateLimited: lockbox
        });

        xWELL(xwellProxy).initialize(
            tokenName,
            tokenSymbol,
            tokenOwner,
            _newRateLimits,
            newPauseDuration,
            newPauseGuardian
        );
    }

    /// @notice deploy lock box, for use on base only
    /// @param xwell The xWELL token address
    /// @param well The WELL token address
    function deployLockBox(
        address xwell,
        address well
    ) public returns (address) {
        return address(new XERC20Lockbox(xwell, well));
    }
}
// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.28;

// import { IWorldID } from "./interfaces/IWorldID.sol";
// import { ByteHasher } from "./helpers/ByteHasher.sol";

// contract AAVEMiniPool {
//     using ByteHasher for bytes;
    
//     IWorldID internal immutable worldId;
//     uint256 internal immutable externalNullifier;
//     uint256 internal immutable groupId = 1;
    
//     mapping(uint256 => bool) internal nullifierHashes;
//     mapping(address => uint256) public liquidationRewards;
    
//     event LiquidationExecuted(address indexed liquidator, uint256 nullifierHash, uint256 reward);
    
//     constructor(IWorldID _worldId, string memory _appId, string memory _actionId) {
//         worldId = _worldId;
//         externalNullifier = abi.encodePacked(abi.encodePacked(_appId).hashToField(), _actionId).hashToField();
//     }
    
//     function executeLiquidation(
//         address signal,
//         uint256 root,
//         uint256 nullifierHash,
//         uint256[8] calldata proof,
//         address borrower,
//         uint256 amount
//     ) public {
//         // Verify World ID proof for sybil resistance
//         if (nullifierHashes[nullifierHash]) revert("Already liquidated");
        
//         worldId.verifyProof(
//             root,
//             groupId,
//             abi.encodePacked(signal).hashToField(),
//             nullifierHash,
//             externalNullifier,
//             proof
//         );
        
//         nullifierHashes[nullifierHash] = true;
        
//         // Execute AAVE liquidation logic here
//         _performLiquidation(borrower, amount);
        
//         // Reward the liquidator
//         uint256 reward = amount * 5 / 100; // 5% liquidation bonus
//         liquidationRewards[msg.sender] += reward;
        
//         emit LiquidationExecuted(msg.sender, nullifierHash, reward);
//     }
    
//     function _performLiquidation(address borrower, uint256 amount) internal {
//         // Integrate with AAVE lending pool contracts
//         // This would call AAVE's liquidationCall function
//     }
// }
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@worldcoin/world-id-contracts/src/interfaces/IWorldID.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title LiquidationProtocol
 * @dev A DeFi liquidation protocol with World ID verification
 * @notice Allows verified humans to liquidate undercollateralized positions
 */
contract LiquidationProtocol is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /// @dev The World ID instance that will be used for verification
    IWorldID internal immutable worldId;
    
    /// @dev The application's action ID for liquidator registration
    uint256 internal immutable liquidatorActionId;
    
    /// @dev The application's action ID for liquidation execution
    uint256 internal immutable liquidationActionId;

    /// @dev Mapping from nullifier hash to whether it has been used
    mapping(uint256 => bool) internal nullifierHashes;
    
    /// @dev Mapping from liquidator address to verification status
    mapping(address => bool) public verifiedLiquidators;
    
    /// @dev Mapping from liquidator to their registration nullifier
    mapping(address => uint256) public liquidatorNullifiers;

    struct Position {
        address borrower;
        address collateralAsset;
        uint256 collateralAmount;
        address debtAsset;
        uint256 debtAmount;
        uint256 healthFactor; // Scaled by 1e18 (e.g., 1.5e18 = 1.5)
        bool isActive;
    }

    struct LiquidationParams {
        uint256 positionId;
        uint256 liquidationAmount;
        address liquidator;
    }

    /// @dev Counter for position IDs
    uint256 public nextPositionId = 1;
    
    /// @dev Mapping from position ID to position data
    mapping(uint256 => Position) public positions;
    
    /// @dev Liquidation threshold (health factor below which liquidation is allowed)
    uint256 public constant LIQUIDATION_THRESHOLD = 1e18; // 1.0
    
    /// @dev Liquidation bonus (percentage given to liquidator)
    uint256 public liquidationBonus = 500; // 5% (basis points)
    
    /// @dev Maximum liquidation percentage per transaction
    uint256 public maxLiquidationPercent = 5000; // 50%

    event LiquidatorRegistered(address indexed liquidator, uint256 nullifierHash);
    event PositionCreated(uint256 indexed positionId, address indexed borrower);
    event PositionLiquidated(
        uint256 indexed positionId, 
        address indexed liquidator, 
        uint256 liquidationAmount,
        uint256 bonus
    );
    event HealthFactorUpdated(uint256 indexed positionId, uint256 newHealthFactor);

    error InvalidNullifier();
    error DuplicateNullifier();
    error NotVerifiedLiquidator();
    error PositionNotLiquidatable();
    error InvalidLiquidationAmount();
    error PositionNotActive();

    /// @param _worldId The WorldID instance that will verify the proofs
    /// @param _liquidatorActionId The action ID for liquidator registration
    /// @param _liquidationActionId The action ID for liquidation execution
    constructor(
        IWorldID _worldId, 
        string memory _liquidatorAppId, 
        string memory _liquidatorAction,
        string memory _liquidationAppId,
        string memory _liquidationAction
    ) Ownable(msg.sender) {
        worldId = _worldId;
        liquidatorActionId = abi.encodePacked(_liquidatorAppId, _liquidatorAction).hashToField();
        liquidationActionId = abi.encodePacked(_liquidationAppId, _liquidationAction).hashToField();
    }

    /// @param root The root of the Merkle tree (returned by the JS widget).
    /// @param nullifierHash The nullifier hash for this proof, preventing double signaling (returned by the JS widget).
    /// @param proof The zero-knowledge proof that demonstrates the claimer is registered with World ID (returned by the JS widget).
    function registerLiquidator(
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) public {
        // First, we make sure this person hasn't already registered
        if (nullifierHashes[nullifierHash]) revert DuplicateNullifier();

        // We now verify the provided proof is valid and the user is verified by World ID
        worldId.verifyProof(
            root,
            liquidatorActionId,
            abi.encodePacked(msg.sender).hashToField(),
            nullifierHash,
            liquidatorActionId,
            proof
        );

        // We now record the user has registered and store their nullifier hash
        nullifierHashes[nullifierHash] = true;
        verifiedLiquidators[msg.sender] = true;
        liquidatorNullifiers[msg.sender] = nullifierHash;

        emit LiquidatorRegistered(msg.sender, nullifierHash);
    }

    /// @dev Create a new borrowing position
    function createPosition(
        address collateralAsset,
        uint256 collateralAmount,
        address debtAsset,
        uint256 debtAmount
    ) external {
        // Transfer collateral to contract
        IERC20(collateralAsset).safeTransferFrom(msg.sender, address(this), collateralAmount);
        
        // Calculate initial health factor (simplified)
        uint256 healthFactor = calculateHealthFactor(collateralAsset, collateralAmount, debtAsset, debtAmount);
        
        // Create position
        positions[nextPositionId] = Position({
            borrower: msg.sender,
            collateralAsset: collateralAsset,
            collateralAmount: collateralAmount,
            debtAsset: debtAsset,
            debtAmount: debtAmount,
            healthFactor: healthFactor,
            isActive: true
        });

        emit PositionCreated(nextPositionId, msg.sender);
        nextPositionId++;
    }

    /// @dev Execute liquidation with World ID verification
    function liquidatePosition(
        uint256 positionId,
        uint256 liquidationAmount,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) external nonReentrant {
        // Verify liquidator is registered
        if (!verifiedLiquidators[msg.sender]) revert NotVerifiedLiquidator();
        
        // Verify liquidation proof (different action from registration)
        worldId.verifyProof(
            root,
            liquidationActionId,
            abi.encodePacked(msg.sender, positionId, liquidationAmount).hashToField(),
            nullifierHash,
            liquidationActionId,
            proof
        );

        Position storage position = positions[positionId];
        
        // Validate position
        if (!position.isActive) revert PositionNotActive();
        if (position.healthFactor >= LIQUIDATION_THRESHOLD) revert PositionNotLiquidatable();
        
        // Validate liquidation amount
        uint256 maxLiquidatable = (position.debtAmount * maxLiquidationPercent) / 10000;
        if (liquidationAmount > maxLiquidatable || liquidationAmount == 0) {
            revert InvalidLiquidationAmount();
        }

        // Calculate collateral to seize
        uint256 collateralToSeize = calculateCollateralToSeize(
            position.collateralAsset,
            position.debtAsset,
            liquidationAmount
        );
        
        // Calculate liquidation bonus
        uint256 bonus = (collateralToSeize * liquidationBonus) / 10000;
        uint256 totalSeized = collateralToSeize + bonus;

        // Transfer debt token from liquidator to position borrower
        IERC20(position.debtAsset).safeTransferFrom(msg.sender, position.borrower, liquidationAmount);
        
        // Transfer collateral + bonus to liquidator
        IERC20(position.collateralAsset).safeTransfer(msg.sender, totalSeized);

        // Update position
        position.debtAmount -= liquidationAmount;
        position.collateralAmount -= totalSeized;
        
        // Recalculate health factor
        if (position.debtAmount > 0) {
            position.healthFactor = calculateHealthFactor(
                position.collateralAsset,
                position.collateralAmount,
                position.debtAsset,
                position.debtAmount
            );
        } else {
            // Position fully liquidated
            position.isActive = false;
        }

        emit PositionLiquidated(positionId, msg.sender, liquidationAmount, bonus);
        emit HealthFactorUpdated(positionId, position.healthFactor);
    }

    /// @dev Update health factor for a position (would typically be called by oracle)
    function updateHealthFactor(uint256 positionId, uint256 newHealthFactor) external onlyOwner {
        Position storage position = positions[positionId];
        require(position.isActive, "Position not active");
        
        position.healthFactor = newHealthFactor;
        emit HealthFactorUpdated(positionId, newHealthFactor);
    }

    /// @dev Get liquidatable positions
    function getLiquidatablePositions() external view returns (uint256[] memory) {
        uint256[] memory liquidatableIds = new uint256[](nextPositionId - 1);
        uint256 count = 0;
        
        for (uint256 i = 1; i < nextPositionId; i++) {
            if (positions[i].isActive && positions[i].healthFactor < LIQUIDATION_THRESHOLD) {
                liquidatableIds[count] = i;
                count++;
            }
        }
        
        // Resize array to actual count
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = liquidatableIds[i];
        }
        
        return result;
    }

    /// @dev Calculate health factor (simplified - would use oracles in production)
    function calculateHealthFactor(
        address collateralAsset,
        uint256 collateralAmount,
        address debtAsset,
        uint256 debtAmount
    ) internal pure returns (uint256) {
        // Simplified calculation - in production, use price oracles
        // Assuming 1:1 price ratio for demo
        return (collateralAmount * 1e18) / debtAmount;
    }

    /// @dev Calculate collateral to seize for liquidation
    function calculateCollateralToSeize(
        address collateralAsset,
        address debtAsset,
        uint256 liquidationAmount
    ) internal pure returns (uint256) {
        // Simplified calculation - would use price oracles in production
        return liquidationAmount; // 1:1 ratio for demo
    }

    /// @dev Set liquidation bonus (only owner)
    function setLiquidationBonus(uint256 _liquidationBonus) external onlyOwner {
        require(_liquidationBonus <= 2000, "Bonus too high"); // Max 20%
        liquidationBonus = _liquidationBonus;
    }

    /// @dev Emergency pause function
    function pause() external onlyOwner {
        // Implementation for pause functionality
    }
}

// Helper library for hash-to-field conversion
library ByteHasher {
    /// @dev Creates a keccak256 hash of a bytestring.
    /// @param value The bytestring to hash
    /// @return The hash of the specified value
    /// @dev `>> 8` makes sure that the result is included in our field
    function hashToField(bytes memory value) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(value))) >> 8;
    }
}

/**
 * @title LiquidationOracle
 * @dev Oracle contract for price feeds and health factor calculations
 */
contract LiquidationOracle is Ownable {
    mapping(address => uint256) public assetPrices; // Price in USD with 8 decimals
    mapping(address => uint256) public collateralFactors; // Collateral factor with 4 decimals (7500 = 75%)
    
    event PriceUpdated(address indexed asset, uint256 price);
    event CollateralFactorUpdated(address indexed asset, uint256 factor);

    constructor() Ownable(msg.sender) {}

    function updatePrice(address asset, uint256 price) external onlyOwner {
        assetPrices[asset] = price;
        emit PriceUpdated(asset, price);
    }

    function updateCollateralFactor(address asset, uint256 factor) external onlyOwner {
        require(factor <= 10000, "Factor too high");
        collateralFactors[asset] = factor;
        emit CollateralFactorUpdated(asset, factor);
    }

    function calculateHealthFactor(
        address collateralAsset,
        uint256 collateralAmount,
        address debtAsset,
        uint256 debtAmount
    ) external view returns (uint256) {
        uint256 collateralPrice = assetPrices[collateralAsset];
        uint256 debtPrice = assetPrices[debtAsset];
        uint256 collateralFactor = collateralFactors[collateralAsset];
        
        require(collateralPrice > 0 && debtPrice > 0, "Price not set");
        require(collateralFactor > 0, "Collateral factor not set");
        
        uint256 collateralValue = (collateralAmount * collateralPrice * collateralFactor) / 10000;
        uint256 debtValue = debtAmount * debtPrice;
        
        return (collateralValue * 1e18) / debtValue;
    }
}

/**
 * @title LiquidationFactory
 * @dev Factory contract to deploy liquidation pools for different asset pairs
 */
contract LiquidationFactory is Ownable {
    address public immutable worldId;
    address public immutable oracle;
    
    mapping(bytes32 => address) public liquidationPools;
    address[] public allPools;
    
    event PoolCreated(
        address indexed collateralAsset,
        address indexed debtAsset,
        address pool
    );

    constructor(address _worldId, address _oracle) Ownable(msg.sender) {
        worldId = _worldId;
        oracle = _oracle;
    }

    function createLiquidationPool(
        address collateralAsset,
        address debtAsset,
        string memory appId,
        string memory liquidatorAction,
        string memory liquidationAction
    ) external onlyOwner returns (address pool) {
        bytes32 salt = keccak256(abi.encodePacked(collateralAsset, debtAsset));
        require(liquidationPools[salt] == address(0), "Pool already exists");
        
        pool = address(new LiquidationProtocol{salt: salt}(
            IWorldID(worldId),
            appId,
            liquidatorAction,
            appId,
            liquidationAction
        ));
        
        liquidationPools[salt] = pool;
        allPools.push(pool);
        
        emit PoolCreated(collateralAsset, debtAsset, pool);
    }

    function getPool(address collateralAsset, address debtAsset) external view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(collateralAsset, debtAsset));
        return liquidationPools[salt];
    }

    function getAllPools() external view returns (address[] memory) {
        return allPools;
    }
}
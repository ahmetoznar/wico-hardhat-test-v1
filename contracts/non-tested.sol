    //SPDX-License-Identifier: Unlicense
    pragma solidity ^0.8.0;

    import "hardhat/console.sol";
    import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
    import "@openzeppelin/contracts/utils/Counters.sol";
    import "@openzeppelin/contracts/utils/Strings.sol";
    import "@openzeppelin/contracts/security/Pausable.sol";
    import "@openzeppelin/contracts/access/Ownable.sol";
    import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
    import "@openzeppelin/contracts/utils/math/SafeMath.sol";
    import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
    import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

    contract Brand is ERC721URIStorage, Pausable, Ownable, ReentrancyGuard {
        using Counters for Counters.Counter;
        using SafeMath for uint256;

        struct UserData {
            bool isWithdraw;
            uint256 mintCount;
            uint256 depositCount;
            uint256 lastProcessTime;
            uint256 depositedValue;
            userNFTCategory userNFTVesting;
        }

        struct userNFTCategory {
            uint256 diamondCategoryCount;
            uint256 pearlCategoryCount;
            uint256 goldCategoryCount;
            uint256 silverCategoryCount;
            uint256 bronzeCategoryCount;
        }

        struct nftCategory {
            uint256 categoryId;
            uint256 categoryPrice;
        }

        Counters.Counter public MINTED;
        address public FEE_ADDRESS;
        uint256 public MAX_MINT_COUNT;
        uint256 public START_TIME;
        uint256 public END_TIME;
        uint256 public DEPOSIT_START_TIME;
        uint256 public DEPOSIT_END_TIME;
        IERC20 public STABLE_TOKEN;
        bytes32 private MERKLE_ROOT;

        uint256 public totalDepositedValue;
        string public baseTokenURI;

        mapping(address => UserData) private userData;
        mapping(uint256 => nftCategory) public categories; // 0 -> diamond, 1 -> pearl, 2 -> gold, 3 -> silver, 4 -> bronze
        mapping(address => bool) private excludeFromFee;
        mapping(uint256 => bool) public isTokenSoldByBrand;
        mapping(address => uint256) public excludeFromFeeID;

        event Minted(address from, uint256 tokenID, uint256 timeStamp);
        event UserDeposit(address from, uint256 value, uint256 timeStamp);
        event Withdraw(address from, uint256 timeStamp);

        constructor() ERC721("Brand NFT Collection", "BNC") {}

        function _baseURI() internal view virtual override returns (string memory) {
            return baseTokenURI;
        }

        function setBaseURI(string memory baseURI) public onlyOwner nonReentrant {
            baseTokenURI = baseURI;
        }

        function setSettings(
            address _address,
            uint256 _maxMint,
            uint256 _startTime,
            uint256 _endTime,
            uint256 _depositStartTime,
            uint256 _depositEndTime,
            IERC20 _stableToken
        ) external onlyOwner nonReentrant {
            FEE_ADDRESS = _address;
            MAX_MINT_COUNT = _maxMint;
            START_TIME = _startTime;
            END_TIME = _endTime;
            DEPOSIT_START_TIME = _depositStartTime;
            DEPOSIT_END_TIME = _depositEndTime;
            STABLE_TOKEN = _stableToken;
        }

        function setMerkleRoot(bytes32 _merkleRoot)
            external
            onlyOwner
            nonReentrant
        {
            MERKLE_ROOT = _merkleRoot;
        }

        function setExclude(
            address _address,
            bool _isExclude,
            uint256 _excludeFromFeeID
        ) external onlyOwner nonReentrant {
            excludeFromFee[_address] = _isExclude;
            excludeFromFeeID[_address] = _excludeFromFeeID;
            isTokenSoldByBrand[_excludeFromFeeID] = true;
        }

        function setPause() external onlyOwner nonReentrant {
            _pause();
        }

        function setUnpause() external onlyOwner nonReentrant {
            _unpause();
        }

        function withdrawAdmin() external onlyOwner nonReentrant {
            require(
                STABLE_TOKEN.transfer(FEE_ADDRESS, totalDepositedValue),
                "transfer failed"
            );
        }

        function mint(
            uint256 _tokenID,
            uint256[2] calldata _data,
            uint256[] memory _proof
        ) external nonReentrant whenNotPaused {
            require(block.timestamp > START_TIME, "mint is not started");
            require(block.timestamp < END_TIME, "mint is finished");
            require(_tokenID > 0 && _tokenID <= 1001, "invalid token id");
            bool _isTokenSold = isTokenSoldByBrand[_tokenID];
            require(!_isTokenSold, "unlucky token already sold by brand");
            UserData storage user = userData[msg.sender];

            uint256 __tokenID = _tokenID;
            uint256 mintPrice = 0;

            if (!excludeFromFee[msg.sender]) {
                //if user needs whitelist

                nftCategory storage category = returnCategoryFromTokenId(__tokenID);
                mintPrice = _getMintPrice(category.categoryId);
                uint256 userNftCount = 0;
                if (category.categoryId == 0) {
                    userNftCount = user.userNFTVesting.diamondCategoryCount;
                } else if (category.categoryId == 1) {
                    userNftCount = user.userNFTVesting.pearlCategoryCount;
                } else if (category.categoryId == 2) {
                    userNftCount = user.userNFTVesting.goldCategoryCount;
                } else if (category.categoryId == 3) {
                    userNftCount = user.userNFTVesting.silverCategoryCount;
                } else if (category.categoryId == 4) {
                    userNftCount = user.userNFTVesting.bronzeCategoryCount;
                }
                require(userNftCount > 0, "insufficent balance");
                require(user.mintCount.add(1) <= MAX_MINT_COUNT, "limit exceed");
                require(!user.isWithdraw, "opps!");
                require(
                    user.depositedValue.sub(mintPrice) != 0,
                    "insufficent deposited value"
                );
                bytes32 userLeaf = keccak256(abi.encodePacked(msg.sender, _data))
                bytes32 _userLeaf = keccak256(abi.encodePacked(userLeaf));
                
                require(MerkleProof.verify(_proof, MERKLE_ROOT, _userLeaf), "leaf is not correct");
                user.depositedValue = user.depositedValue.sub(mintPrice);
            } else {
                //if user not needs whitelist
                __tokenID = excludeFromFeeID[msg.sender];
                require(user.mintCount.add(1) <= MAX_MINT_COUNT, "limit exceed");
            }

            user.lastProcessTime = block.timestamp;
            user.mintCount = user.mintCount.add(1);
            _mint(msg.sender, __tokenID);
            _setTokenURI(__tokenID, Strings.toString(__tokenID));
            MINTED.increment();

            emit Minted(msg.sender, _tokenID, block.timestamp);
        }

        function getLeaf(address _address, uint256[2] calldata _data)
            external
            view
            returns (bytes32)
        {
            bytes32 userLeaf = keccak256(abi.encodePacked(_address, _data)); 
            bytes32 _userLeaf = keccak256(abi.encodePacked(userLeaf));
            return _userLeaf;
        }

        function deposit(uint256 _categoryId) external nonReentrant whenNotPaused {
            require(
                block.timestamp > DEPOSIT_START_TIME,
                "deposit period is not available"
            );
            require(_categoryId < 5 && _categoryId >= 0, "invalid category id");
            require(block.timestamp < DEPOSIT_END_TIME, "deposit period is closed");
            UserData storage user = userData[msg.sender];
            require(user.depositCount.add(1) <= MAX_MINT_COUNT, "too many mint");
            uint256 depositPrice = _getMintPrice(_categoryId);
            require(depositPrice != 0, "invalid token id");
            require(
                STABLE_TOKEN.transferFrom(msg.sender, address(this), depositPrice)
            );

            if (_categoryId == 0) {
                user.userNFTVesting.diamondCategoryCount = user
                    .userNFTVesting
                    .diamondCategoryCount
                    .add(1);
            } else if (_categoryId == 1) {
                user.userNFTVesting.pearlCategoryCount = user
                    .userNFTVesting
                    .pearlCategoryCount
                    .add(1);
            } else if (_categoryId == 2) {
                user.userNFTVesting.goldCategoryCount = user
                    .userNFTVesting
                    .goldCategoryCount
                    .add(1);
            } else if (_categoryId == 3) {
                user.userNFTVesting.silverCategoryCount = user
                    .userNFTVesting
                    .silverCategoryCount
                    .add(1);
            } else if (_categoryId == 4) {
                user.userNFTVesting.bronzeCategoryCount = user
                    .userNFTVesting
                    .bronzeCategoryCount
                    .add(1);
            }

            user.lastProcessTime = block.timestamp;
            user.depositedValue = user.depositedValue.add(depositPrice);
            user.depositCount = user.depositCount.add(1);
            totalDepositedValue = totalDepositedValue.add(depositPrice);

            emit UserDeposit(msg.sender, depositPrice, block.timestamp);
        }

        function withdraw() external nonReentrant whenNotPaused {
            require(block.timestamp > START_TIME, "too early");
            UserData storage user = userData[msg.sender];
            require(totalDepositedValue > 0);
            totalDepositedValue = totalDepositedValue.sub(user.depositedValue);
            user.isWithdraw = true;
            user.depositedValue = 0;
            user.depositCount = 0;
            require(
                STABLE_TOKEN.transfer(msg.sender, user.depositedValue),
                "transfer failed"
            );
        }


        function setCategory(uint256 _categoryId, uint256 _price)
            external
            onlyOwner
            nonReentrant
        {
            categories[_categoryId].categoryId = _categoryId;
            categories[_categoryId].categoryPrice = _price;
        }

        function returnCategory(uint256 _categoryId)
            public
            view
            returns (nftCategory memory)
        {
            nftCategory memory _nftCategory = categories[_categoryId];
            return _nftCategory;
        }

        function returnCategoryFromTokenId(uint256 _tokenID)
            private
            view
            returns (nftCategory memory)
        {
            if (_tokenID == 1) {
                // diamond
                nftCategory memory _nftCategory = categories[0];
                return _nftCategory;
            } else if (_tokenID >= 2 && _tokenID <= 9) {
                // pearl
                nftCategory memory _nftCategory = categories[1];
                return _nftCategory;
            } else if (_tokenID >= 10 && _tokenID <= 39) {
                // gold
                nftCategory memory _nftCategory = categories[2];
                return _nftCategory;
            } else if (_tokenID >= 40 && _tokenID <= 139) {
                // silver
                nftCategory memory _nftCategory = categories[3];
                return _nftCategory;
            } else if (_tokenID >= 140 && _tokenID <= 1001) {
                // bronze
                nftCategory memory _nftCategory = categories[4];
                return _nftCategory;
            } else {
                nftCategory memory _nftCategory = categories[0];
                return _nftCategory;
            }
        }

        function _getMintPrice(uint256 _categoryId) public view returns (uint256) {
            if (_categoryId == 0) {
                // diamond
                return categories[0].categoryPrice;
            } else if (_categoryId == 1) {
                // pearl
                return categories[1].categoryPrice;
            } else if (_categoryId == 2) {
                // gold
                return categories[2].categoryPrice;
            } else if (_categoryId == 3) {
                // silver
                return categories[3].categoryPrice;
            } else if (_categoryId == 4) {
                // bronze
                return categories[4].categoryPrice;
            } else {
                return 0;
            }
        }

        function getUserData(address _address)
            external
            view
            returns (UserData memory)
        {
            UserData memory data = userData[_address];
            return data;
        }

        function getMerkleRoot() external view returns (bytes32) {
            return MERKLE_ROOT;
        }
    }

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface matrix {
    function users(
        address _user
    )
        external
        view
        returns (
            bool isRegistered,
            address referrer,
            uint256 numPartners,
            uint256 directs,
            uint256 rank,
            uint256 totalDirectBonusDistributed,
            uint256 totalTeamBonusDistributed
        );
}

contract GlobalMatrixInvestmentPlan {
    IERC20 public token = IERC20(0x55d398326f99059fF775485246999027B3197955);
    address public admin;
    matrix public tct;
    uint256 public totalDeposits;
    uint256 public totalRewards;
    uint256 public members;
    uint256 public maxdeposit = 100;
    uint256 public foundercooldown = 48 days;
    uint256 public membercooldown = 72 days;
    uint256 public subcriptionFee = 50 ether;
    uint256 public depositGasFee = 0.001 ether;
    uint256 public wthdrawGasFee = 0.002 ether;
    bool public membershipEnabled = true;
    bool public witdrawTimerenabled = true;

    struct Deposit {
        uint256 amount;
        uint256 reward;
        uint256 available;
        bool withdrawn;
    }

    struct User {
        mapping(uint256 => Deposit) planDeposits;
        mapping(uint256 => uint256) planRewards;
        mapping(uint256 => uint256) plantotalDeposits;
        uint256 totalDeposits;
        uint256 totalDepositsAmount;
        uint256 totalRewards;
        bool registerd;
        uint256 lastwithdrawn;
        bool blacklisted;
        uint256 maxdeposit;
    }

    struct QueueUser {
        address userAddress;
        uint256 rewardAmount;
        uint256 available;
        uint256 depositnumber;
    }

    struct subscription {
        bool iswhitelisted;
        uint256 time;
    }

    mapping(address => User) public users;
    mapping(uint256 => mapping(uint256 => QueueUser)) public Queue;
    mapping(uint256 => uint256) public QueueCounters;
    mapping(uint256 => uint256) public LastProcessed;
    mapping(address => bool) public founder;
    mapping(address => subscription) public subscriptions;

    uint256[3] planDepositAmount = [50 ether, 100 ether, 500 ether];
    uint256[3] planRewardAmount = [60 ether, 120 ether, 600 ether];
    uint256[3] planLevelAmount = [5 ether, 10 ether, 50 ether];
    uint256[3] planMaxlevel = [10, 10, 10];

    constructor() {
        admin = 0xF4600E2F87F2eD80ec0f2d2C5A6AD28AC31AfE6F;
        tct = matrix(0x671AF6aAC0Ed3BAffA46d1DA0E7FeBa0f8672E85);
    }

    function _deposit(uint256 _plan) public payable {
        (bool registerd, , , , , , ) = tct.users(msg.sender);
        require(registerd, "you must register in TCT plus");
        require(msg.value == depositGasFee, "GAS FEE needs to be paid");
        require(_plan < planDepositAmount.length, "Select the right plan");
        User storage user = users[msg.sender];
        if (user.maxdeposit == 0) {
            require(
                user.plantotalDeposits[_plan] <= maxdeposit,
                "max deposit reached"
            );
        } else {
            require(
                user.plantotalDeposits[_plan] <= user.maxdeposit,
                "max deposit reached"
            );
        }
        require(!user.blacklisted, "you are blacklisted");
        require(
            user.planDeposits[_plan].amount == 0,
            "can not deposit again withdraw first"
        );

        if (!user.registerd) {
            members++;
            user.registerd = true;
            user.lastwithdrawn = block.timestamp;
            subscriptions[msg.sender].time = block.timestamp + 30 days;
        }

        token.transferFrom(msg.sender, address(this), planDepositAmount[_plan]);
        payable(admin).transfer(msg.value);
        processQueue(_plan);

        user.planDeposits[_plan] = (
            Deposit(planDepositAmount[_plan], planRewardAmount[_plan], 0, false)
        );
        Queue[_plan][QueueCounters[_plan]] = QueueUser(
            msg.sender,
            planRewardAmount[_plan],
            0,
            user.plantotalDeposits[_plan]
        );

        QueueCounters[_plan]++;
        user.plantotalDeposits[_plan]++;
        user.totalDeposits++;
        user.totalDepositsAmount += planDepositAmount[_plan];
        totalDeposits += planDepositAmount[_plan];
    }

    function processQueue(uint256 _plan) internal {
        uint256 count = 0;
        for (
            uint256 i = LastProcessed[_plan];
            i <= QueueCounters[_plan] && count <= planMaxlevel[_plan];
            i++
        ) {
            if (
                Queue[_plan][i].userAddress != address(0) &&
                Queue[_plan][i].available < Queue[_plan][i].rewardAmount
            ) {
                Queue[_plan][i].available += planLevelAmount[_plan];
                users[Queue[_plan][i].userAddress]
                    .planDeposits[_plan]
                    .available += planLevelAmount[_plan];
                count++;
            } else if (
                Queue[_plan][i].userAddress != address(0) &&
                Queue[_plan][i].available == Queue[_plan][i].rewardAmount
            ) {
                LastProcessed[_plan] = i;
            }
        }
    }

    function withdraw(uint256 _plan) public payable {
        require(msg.value == wthdrawGasFee, "GAS FEE needs to be paid");
        if (membershipEnabled) {
            require(
                subscriptions[msg.sender].iswhitelisted ||
                    block.timestamp < subscriptions[msg.sender].time,
                "your subscription in TCT is over"
            );
        }
        User storage user = users[msg.sender];
        require(!user.blacklisted, "blacklisted");
        require(
            user.planDeposits[_plan].available >=
                user.planDeposits[_plan].reward,
            "can not withdraw yet amount not reached"
        );
        if (witdrawTimerenabled) {
            if (founder[msg.sender]) {
                require(
                    block.timestamp > user.lastwithdrawn + foundercooldown,
                    "founer can only withdraw once in timeline"
                );
            } else {
                require(
                    block.timestamp > user.lastwithdrawn + membercooldown,
                    "user can only withdraw once in timeline"
                );
            }
        }

        require(
            user.planDeposits[_plan].amount != 0,
            "can not withdraw  deposit first"
        );
        uint256 amount;
        if (
            !user.planDeposits[_plan].withdrawn &&
            user.planDeposits[_plan].available >=
            user.planDeposits[_plan].reward
        ) {
            amount = user.planDeposits[_plan].reward;
            totalRewards += user.planDeposits[_plan].reward;
            delete users[msg.sender].planDeposits[_plan];
        }

        token.transfer(msg.sender, amount);
        payable(admin).transfer(msg.value);
        user.lastwithdrawn = block.timestamp;
        user.planRewards[_plan] += amount;
    }

    function withdrawable(
        address _user,
        uint256 _plan
    ) public view returns (uint256 amount) {
        User storage user = users[_user];
        if (
            !user.planDeposits[_plan].withdrawn &&
            user.planDeposits[_plan].available >=
            user.planDeposits[_plan].reward
        ) {
            amount = user.planDeposits[_plan].available;
        }

        return amount;
    }

    function earned(
        address _user,
        uint256 _plan
    ) public view returns (uint256 amount) {
        User storage user = users[_user];
        if (
            !user.planDeposits[_plan].withdrawn &&
            user.planDeposits[_plan].available <=
            user.planDeposits[_plan].reward
        ) {
            amount = user.planDeposits[_plan].available;
        }

        return amount;
    }

    function subscribe(uint256 months) external {
        require(months > 0);
        require(membershipEnabled, "membership is not enabled");
        (bool registerd, , , , , , ) = tct.users(msg.sender);
        require(registerd, "you must register in TCT plus");
        require(block.timestamp > subscriptions[msg.sender].time);
        token.transferFrom(msg.sender, admin, months * subcriptionFee);
        subscriptions[msg.sender].time = block.timestamp + (months * 30 days);
    }

    function whitelistSubcription(address _user, bool value) external {
        require(msg.sender == admin);
        subscriptions[_user].iswhitelisted = value;
    }

    // to set membership
    function Setmembership(bool _membership) external {
        require(msg.sender == admin);
        require(
            _membership != membershipEnabled,
            " membership already in same state"
        );
        membershipEnabled = _membership;
    }

    function SetwitdrawTimerenabled(bool _witdrawTimerenabled) external {
        require(msg.sender == admin);
        require(
            _witdrawTimerenabled != witdrawTimerenabled,
            " witdraw Timer already in same state"
        );
        witdrawTimerenabled = _witdrawTimerenabled;
    }

    function changewithdrawGasFee(uint256 _withdrawGasFee) external {
        // Ensure that the new joining fee is greater than 0
        require(msg.sender == admin);
        wthdrawGasFee = _withdrawGasFee;
    }

    function changedepositGasFee(uint256 _depositGasFee) external {
        // Ensure that the new joining fee is greater than 0
        require(msg.sender == admin);
        depositGasFee = _depositGasFee;
    }

    function changesubcriptionFee(uint256 _subcriptionFee) external {
        // Ensure that the new joining fee is greater than 0
        require(msg.sender == admin);
        require(_subcriptionFee > 0, "Joining fee must be greater than 0");
        subcriptionFee = _subcriptionFee;
    }

    function changemaxdeposit(uint256 _maxdeposit) external {
        // Ensure that the new joining fee is greater than 0
        require(msg.sender == admin);
        require(_maxdeposit > 0, "Joining fee must be greater than 0");
        maxdeposit = _maxdeposit;
    }

    function changeadmin(address _admin) external {
        // Ensure that the new joining fee is greater than 0
        require(msg.sender == admin);
        admin = _admin;
    }

    function changeCooldowntimer(
        uint256 _foudercooldown,
        uint256 _membercooldown
    ) external {
        // Ensure that the new joining fee is greater than 0
        require(msg.sender == admin);
        foundercooldown = _foudercooldown;
        membercooldown = _membercooldown;
    }

    function Blacklist(address[] memory _users, bool choice) external {
        // Ensure that the new joining fee is greater than 0
        require(msg.sender == admin);
        for (uint256 i = 0; i < _users.length; i++) {
            users[_users[i]].blacklisted = choice;
        }
    }

    function maxdepositperuser(
        address[] memory _users,
        uint256 amount
    ) external {
        // Ensure that the new joining fee is greater than 0
        require(msg.sender == admin);
        for (uint256 i = 0; i < _users.length; i++) {
            users[_users[i]].maxdeposit = amount;
        }
    }

    function setFounder(address[] memory _users, bool choice) external {
        require(msg.sender == admin);
        for (uint256 i = 0; i < _users.length; i++) {
            founder[_users[i]] = choice;
        }
    }

    // to withdraw token
    function withdrawToken(address _token, uint256 _amount) external {
        require(msg.sender == admin);
        // Check if the token address is not a null address
        require(
            _token != address(0),
            "The token address cannot be a null address (0x0)"
        );
        // Check if the amount to withdraw is positive
        require(
            _amount > 0,
            "The amount to withdraw must be greater than zero"
        );
        // Check if the contract has sufficient balance of the token
        require(
            IERC20(_token).balanceOf(address(this)) >= _amount,
            "The contract has insufficient balance of the token"
        );
        // Transfer the tokens to the admin
        IERC20(_token).transfer(admin, _amount);
    }
}
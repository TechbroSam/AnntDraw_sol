// SPDX-License-Identifier: GPL-3.0
import "@openzeppelin/contracts/utils/Strings.sol";

pragma solidity >=0.5.11 <0.9.0;

contract Lottery {
    uint256 public ticketPrice = 0.01 ether;
    uint256 public maxTickets = 150; // maximum tickets per lottery
    uint256 public ticketCommission = 0.001 ether; // commission per ticket
    uint256 private duration = 5040 minutes; // The duration set for the lottery
    uint256 public maxTicketsPerAddress = 5; // maximum tickets allowed per wallet address

    uint256 public expiration; // Timeout in case That the lottery was not carried out.
    address public lotteryOperator; // the crator of the lottery
    uint256 public operatorTotalCommission = 0; // the total commission balance
    address public lastWinner; // the last winner of the lottery
    uint256 public lastWinnerAmount; // the last winner amount of the lottery

    mapping(address => uint256) public winnings; // maps the winners to there winnings
    address[] public tickets; //array of purchased Tickets

    // modifier to check if caller is the lottery operator
    modifier isOperator() {
        require(
            (msg.sender == lotteryOperator),
            "Caller is not the lottery operator"
        );
        _;
    }

    // Function to change the ticket price, maximum tickets and ticket commission
    function updateLotteryParams(
        uint256 newTicketPriceInEther,
        uint256 newMaxTickets,
        uint256 newTicketCommissionInEther
    ) external isOperator {
        ticketPrice = newTicketPriceInEther;
        maxTickets = newMaxTickets;
        ticketCommission = newTicketCommissionInEther;
    }

    // Function to set the maximum tickets allowed per wallet address
    function setMaxTicketsPerAddress(
        uint256 newMaxTicketsPerAddress
    ) external isOperator {
        maxTicketsPerAddress = newMaxTicketsPerAddress;
    }

    // modifier to check if caller is a winner
    modifier isWinner() {
        require(IsWinner(), "Caller is not a winner");
        _;
    }

    constructor() {
        lotteryOperator = msg.sender;
        expiration = block.timestamp + duration;
    }

    // return all the tickets
    function getTickets() public view returns (address[] memory) {
        return tickets;
    }

    function getWinningsForAddress(address addr) public view returns (uint256) {
        return winnings[addr];
    }

    function getNumTicketsPerAddress(
        address addr
    ) internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < tickets.length; i++) {
            if (tickets[i] == addr) {
                count++;
            }
        }
        return count;
    }

    function BuyTickets() public payable {
        if (tickets.length == 0 && block.timestamp >= expiration) {
            // Reset the duration if no tickets were sold and the current duration has expired
            expiration = block.timestamp + duration;
        }

        require(
            msg.value % ticketPrice == 0,
            string.concat(
                "the value must be multiple of ",
                Strings.toString(ticketPrice),
                " Ether"
            )
        );
        uint256 numOfTicketsToBuy = msg.value / ticketPrice;

        require(
            numOfTicketsToBuy <= RemainingTickets(),
            "Not enough tickets available."
        );

        require(
            getNumTicketsPerAddress(msg.sender) + numOfTicketsToBuy <=
                maxTicketsPerAddress,
            "Max tickets per address exceeded."
        );

        for (uint256 i = 0; i < numOfTicketsToBuy; i++) {
            tickets.push(msg.sender);
        }
    }

    function DrawWinnerTicket() public isOperator {
        require(tickets.length > 0, "No tickets were purchased");

        bytes32 blockHash = blockhash(block.number - tickets.length);
        uint256 randomNumber = uint256(
            keccak256(abi.encodePacked(block.timestamp, blockHash))
        );
        uint256 winningTicket = randomNumber % tickets.length;

        address winner = tickets[winningTicket];
        lastWinner = winner;
        winnings[winner] += (tickets.length * (ticketPrice - ticketCommission));
        lastWinnerAmount = winnings[winner];
        operatorTotalCommission += (tickets.length * ticketCommission);
        delete tickets;
        expiration = block.timestamp + duration;
    }

    function restartDraw() public isOperator {
        require(tickets.length == 0, "Cannot Restart Draw as Draw is in play");

        delete tickets;
        expiration = block.timestamp + duration;
    }

    function checkWinningsAmount() public view returns (uint256) {
        address payable winner = payable(msg.sender);

        uint256 reward2Transfer = winnings[winner];

        return reward2Transfer;
    }

    function WithdrawWinnings() public isWinner {
        address payable winner = payable(msg.sender);

        uint256 reward2Transfer = winnings[winner];
        winnings[winner] = 0;

        winner.transfer(reward2Transfer);
    }

    function RefundAll() public {
        require(block.timestamp >= expiration, "the lottery not expired yet");

        for (uint256 i = 0; i < tickets.length; i++) {
            address payable to = payable(tickets[i]);
            tickets[i] = address(0);
            to.transfer(ticketPrice);
        }
        delete tickets;
    }

    function WithdrawCommission() public isOperator {
        address payable operator = payable(msg.sender);

        uint256 commission2Transfer = operatorTotalCommission;
        operatorTotalCommission = 0;

        operator.transfer(commission2Transfer);
    }

    function IsWinner() public view returns (bool) {
        return winnings[msg.sender] > 0;
    }

    function CurrentWinningReward() public view returns (uint256) {
        return tickets.length * ticketPrice;
    }

    function RemainingTickets() public view returns (uint256) {
        return maxTickets - tickets.length;
    }
}

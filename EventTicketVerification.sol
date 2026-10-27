// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EventTicketVerification {
    address public admin;

    mapping(address => bool) public organizers;

    uint256 public nextEventId = 1;
    uint256 public nextTicketId = 1;

    struct EventInfo {
        string name;
        uint256 date;
        string venue;
        uint256 ticketPrice;
        uint256 maxTickets;
        uint256 ticketsSold;
        bool active;
        address organizer;
    }

    struct TicketInfo {
        uint256 eventId;
        address currentOwner;
        bool used;
        bool cancelled;
        bool exists;
    }

    mapping(uint256 => EventInfo) public eventDetails;
    mapping(uint256 => TicketInfo) public tickets;

    mapping(uint256 => uint256) public eventFunds;
    mapping(address => uint256) public pendingRefunds;

    event OrganizerUpdated(address indexed organizer, bool allowed);
    event EventCreated(uint256 indexed eventId, string name);
    event TicketPurchased(
        uint256 indexed ticketId,
        uint256 indexed eventId,
        address buyer
    );
    event TicketTransferred(
        uint256 indexed ticketId,
        address from,
        address to
    );
    event TicketUsed(uint256 indexed ticketId);
    event TicketCancelled(uint256 indexed ticketId);
    event RefundClaimed(address indexed user, uint256 amount);

    constructor() {
        admin = msg.sender;
        organizers[msg.sender] = true;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Admin only");
        _;
    }

    modifier onlyOrganizer() {
        require(organizers[msg.sender], "Organizer only");
        _;
    }

    modifier eventExists(uint256 eventId) {
        require(
            eventDetails[eventId].organizer != address(0),
            "Event does not exist"
        );
        _;
    }

    modifier ticketExists(uint256 ticketId) {
        require(tickets[ticketId].exists, "Ticket does not exist");
        _;
    }

    // 1. Add or remove an authorized organizer
    function setOrganizer(
        address account,
        bool allowed
    ) external onlyAdmin {
        require(account != address(0), "Invalid address");
        require(account != admin || allowed, "Admin must remain organizer");

        organizers[account] = allowed;
        emit OrganizerUpdated(account, allowed);
    }

    // 2. Create an event
    function createEvent(
        string calldata name,
        uint256 date,
        string calldata venue,
        uint256 ticketPrice,
        uint256 maxTickets
    ) external onlyOrganizer returns (uint256) {
        require(bytes(name).length > 0, "Enter event name");
        require(bytes(venue).length > 0, "Enter venue");
        require(date > block.timestamp, "Date must be in the future");
        require(maxTickets > 0, "Ticket limit must be positive");

        uint256 eventId = nextEventId++;

        eventDetails[eventId] = EventInfo({
            name: name,
            date: date,
            venue: venue,
            ticketPrice: ticketPrice,
            maxTickets: maxTickets,
            ticketsSold: 0,
            active: true,
            organizer: msg.sender
        });

        emit EventCreated(eventId, name);
        return eventId;
    }

    // 3. Purchase a ticket and generate its unique ID
    function buyTicket(
        uint256 eventId
    ) external payable eventExists(eventId) returns (uint256) {
        EventInfo storage eventData = eventDetails[eventId];

        require(eventData.active, "Event is inactive");
        require(block.timestamp < eventData.date, "Event has started");
        require(
            eventData.ticketsSold < eventData.maxTickets,
            "Tickets sold out"
        );
        require(
            msg.value == eventData.ticketPrice,
            "Incorrect ticket price"
        );

        uint256 ticketId = nextTicketId++;

        tickets[ticketId] = TicketInfo({
            eventId: eventId,
            currentOwner: msg.sender,
            used: false,
            cancelled: false,
            exists: true
        });

        eventData.ticketsSold++;
        eventFunds[eventId] += msg.value;

        emit TicketPurchased(ticketId, eventId, msg.sender);
        return ticketId;
    }

    // 4. Verify ticket ID, owner and validity
    function verifyTicket(
        uint256 ticketId,
        address claimedOwner
    )
        external
        view
        returns (
            bool exists,
            bool ownerMatches,
            bool valid,
            address currentOwner,
            bool used,
            bool cancelled
        )
    {
        TicketInfo memory ticket = tickets[ticketId];

        if (!ticket.exists) {
            return (false, false, false, address(0), false, false);
        }

        EventInfo memory eventData = eventDetails[ticket.eventId];

        ownerMatches = ticket.currentOwner == claimedOwner;
        valid = ownerMatches &&
            !ticket.used &&
            !ticket.cancelled &&
            eventData.active;

        return (
            true,
            ownerMatches,
            valid,
            ticket.currentOwner,
            ticket.used,
            ticket.cancelled
        );
    }

    // 5. Mark a ticket as used at the event entrance
    function markTicketAsUsed(
        uint256 ticketId
    ) external ticketExists(ticketId) {
        TicketInfo storage ticket = tickets[ticketId];
        EventInfo storage eventData = eventDetails[ticket.eventId];

        require(
            msg.sender == eventData.organizer || msg.sender == admin,
            "Not authorized"
        );
        require(!ticket.used, "Ticket already used");
        require(!ticket.cancelled, "Ticket cancelled");
        require(eventData.active, "Event is inactive");

        ticket.used = true;

        emit TicketUsed(ticketId);
    }

    // 6. Transfer a ticket to another wallet
    function transferTicket(
        uint256 ticketId,
        address newOwner
    ) external ticketExists(ticketId) {
        TicketInfo storage ticket = tickets[ticketId];
        EventInfo storage eventData = eventDetails[ticket.eventId];

        require(ticket.currentOwner == msg.sender, "Not ticket owner");
        require(newOwner != address(0), "Invalid new owner");
        require(newOwner != msg.sender, "Already the owner");
        require(!ticket.used, "Ticket already used");
        require(!ticket.cancelled, "Ticket cancelled");
        require(eventData.active, "Event is inactive");
        require(block.timestamp < eventData.date, "Event has started");

        address previousOwner = ticket.currentOwner;
        ticket.currentOwner = newOwner;

        emit TicketTransferred(ticketId, previousOwner, newOwner);
    }

    // 7. Cancel a ticket and credit a refund
    function cancelTicket(
        uint256 ticketId
    ) external ticketExists(ticketId) {
        TicketInfo storage ticket = tickets[ticketId];
        EventInfo storage eventData = eventDetails[ticket.eventId];

        require(
            msg.sender == eventData.organizer || msg.sender == admin,
            "Not authorized"
        );
        require(block.timestamp < eventData.date, "Event has started");
        require(!ticket.used, "Ticket already used");
        require(!ticket.cancelled, "Ticket already cancelled");

        ticket.cancelled = true;

        eventFunds[ticket.eventId] -= eventData.ticketPrice;
        pendingRefunds[ticket.currentOwner] += eventData.ticketPrice;

        emit TicketCancelled(ticketId);
    }

    // 8. Let a user claim a credited refund
    function claimRefund() external {
        uint256 amount = pendingRefunds[msg.sender];

        require(amount > 0, "No refund available");

        pendingRefunds[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Refund transfer failed");

        emit RefundClaimed(msg.sender, amount);
    }

    // 9. Allow an organizer to withdraw event funds after its date
    function withdrawEventFunds(
        uint256 eventId
    ) external eventExists(eventId) {
        EventInfo storage eventData = eventDetails[eventId];

        require(
            msg.sender == eventData.organizer || msg.sender == admin,
            "Not authorized"
        );
        require(block.timestamp >= eventData.date, "Event not started yet");

        uint256 amount = eventFunds[eventId];
        require(amount > 0, "No funds available");

        eventFunds[eventId] = 0;

        (bool success, ) = payable(eventData.organizer).call{value: amount}("");
        require(success, "Withdrawal failed");
    }
}

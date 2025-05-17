module MyModule::DigitalBillOfLading {
    use std::string::String;
    use aptos_framework::signer;
    use aptos_framework::timestamp;
    use aptos_framework::event;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_BOL_ALREADY_EXISTS: u64 = 2;
    const E_BOL_DOES_NOT_EXIST: u64 = 3;
    const E_NOT_CURRENT_OWNER: u64 = 4;

    /// Struct representing a digital bill of lading
    struct BillOfLading has key, store {
        id: u64,
        cargo_description: String,
        ship_name: String,
        destination: String,
        shipper: address,
        current_owner: address,
        issue_date: u64
    }

    /// Event emitted when a new bill of lading is created
    struct BolCreationEvent has drop, store {
        id: u64,
        shipper: address,
        owner: address,
        issue_date: u64
    }

    /// Event emitted when a bill of lading is transferred
    struct BolTransferEvent has drop, store {
        id: u64,
        from: address,
        to: address,
        transfer_date: u64
    }

    /// Resource to track bills of lading and events
    struct BolStore has key {
        next_id: u64,
        creation_events: event::EventHandle<BolCreationEvent>,
        transfer_events: event::EventHandle<BolTransferEvent>
    }

    /// Initialize bill of lading store for an account
    public entry fun initialize(account: &signer) {
        let addr = signer::address_of(account);
        if (!exists<BolStore>(addr)) {
            move_to(account, BolStore {
                next_id: 0,
                creation_events: event::new_event_handle<BolCreationEvent>(account),
                transfer_events: event::new_event_handle<BolTransferEvent>(account)
            });
        }
    }

    /// Create a new digital bill of lading
    public entry fun create_bill(
        issuer: &signer,
        cargo_description: String,
        ship_name: String,
        destination: String,
        receiver: address
    ) acquires BolStore {
        let issuer_addr = signer::address_of(issuer);
        
        // Initialize BolStore if it doesn't exist
        if (!exists<BolStore>(issuer_addr)) {
            initialize(issuer);
        }
        
        // Get the next bill ID and increment
        let bol_store = borrow_global_mut<BolStore>(issuer_addr);
        let bol_id = bol_store.next_id;
        bol_store.next_id = bol_id + 1;
        
        // Create bill of lading
        let current_time = timestamp::now_seconds();
        let bol = BillOfLading {
            id: bol_id,
            cargo_description,
            ship_name,
            destination,
            shipper: issuer_addr,
            current_owner: receiver,
            issue_date: current_time
        };
        
        // Emit creation event
        event::emit_event(&mut bol_store.creation_events, BolCreationEvent {
            id: bol_id,
            shipper: issuer_addr,
            owner: receiver,
            issue_date: current_time
        });
        
        // Store in issuer's account
        move_to(issuer, bol);
    }

    /// Transfer ownership of a bill of lading
    public entry fun transfer(
        owner: &signer,
        bol_holder: address,
        bol_id: u64,
        new_owner: address
    ) acquires BillOfLading, BolStore {
        let owner_addr = signer::address_of(owner);
        
        // Get the bill of lading from holder's account
        assert!(exists<BillOfLading>(bol_holder), E_BOL_DOES_NOT_EXIST);
        let bol = borrow_global_mut<BillOfLading>(bol_holder);
        
        // Verify ownership
        assert!(bol.current_owner == owner_addr, E_NOT_AUTHORIZED);
        assert!(bol.id == bol_id, E_BOL_DOES_NOT_EXIST);
        
        // Update ownership
        let old_owner = bol.current_owner;
        bol.current_owner = new_owner;
        
        // Emit transfer event
        let bol_store = borrow_global_mut<BolStore>(bol.shipper);
        event::emit_event(&mut bol_store.transfer_events, BolTransferEvent {
            id: bol_id,
            from: old_owner,
            to: new_owner,
            transfer_date: timestamp::now_seconds()
        });
    }
}
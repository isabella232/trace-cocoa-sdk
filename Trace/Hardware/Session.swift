//
//  Session.swift
//  Trace
//
//  Created by Shams Ahmed on 13/08/2019.
//  Copyright © 2020 Bitrise. All rights reserved.
//

import Foundation

/// Session
final class Session {
    
    // MARK: - Property
    
    private let repeater: Repeater
    private let delay: Double
    
    /// Setter: use method self.updateResource()
    var resource: Resource? {
        didSet {
            resource?.session = uuid.string
            
            if let oldValue = oldValue {
                if oldValue.network?.isEmpty == false && resource?.network?.isEmpty == true {
                    resource?.network = oldValue.network
                }
            } else {
                Logger.debug(.application, "Resource created for this new session")
            }
            
            if let resources = try? resource?.dictionary() {
                // TODO: use enum instead of string
                Trace.shared.crash.userInfo["Resource"] = resources
            }
        }
    }
    
    var uuid: ULID {
        didSet {
            resource?.session = uuid.string
        }
    }
    
    // MARK: - Init
    
    // Update the session every 15 seconds
    internal init(timeout: Double = 15.0, delay: Double = 0.10) {
        self.repeater = Repeater(timeout)
        self.delay = delay
        self.uuid = ULID()

        setup()
    }
    
    // MARK: - Setup
    
    private func setup() {
        let handler: () -> Void = { [weak self] in
            self?.sendHardwareDetails()
        }
        
        repeater.state = .resume
        repeater.handler = handler
        
        // Must use main thread for resource
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: { [weak self] in
                self?.updateResource()
                self?.sendHardwareDetails()
            }
        )
    }
    
    // MARK: - Device
    
    private func updateResource() {
        let deviceFormatter = DeviceFormatter()
        
        resource = Resource(from: deviceFormatter.details)
    }
    
    private func sendHardwareDetails() {
        let cpu = CPU()
        let memory = Memory()
        let connectivity = Connectivity()
        let hardwareFormatter = HardwareFormatter(
            cpu: cpu,
            memory: memory,
            connectivity: connectivity
        )
        
        if let interface = connectivity.interface.interface {
            resource?.network = interface
        }
        
        Trace.shared.queue.add(hardwareFormatter.metrics)
    }
    
    // MARK: - State
    
    func restart() {
        repeater.state = .resume
        
        DispatchQueue.main.async { [weak self] in
            self?.updateResource()
            self?.sendHardwareDetails()
        }
        
        uuid = ULID()
    }
}

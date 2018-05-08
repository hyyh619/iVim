//
//  ExtendedKeyboardConfigNodes.swift
//  iVim
//
//  Created by Terry Chou on 2018/5/8.
//  Copyright © 2018 Boogaloo. All rights reserved.
//

import Foundation

private let kType = "type"
private let kTitle = "title"
private let kContents = "contents"
private let kKeys = "keys"
private let kOperation = "operation"
private let kLocations = "locations"
private let kButtons = "buttons"
private let kArguments = "arguments"

typealias NodeArray = [Any]
typealias NodeDict = [String: Any]

enum EKError: Error {
    case info(String)
}

enum EKOperation: String {
    case append
    case insert
    case remove
    case replace
    case apply
    case clear
    case `default`
    case source
    
    init?(name: String?) {
        guard let n = name else { return nil }
        self.init(rawValue: n)
    }
}

enum EKKeyType: String {
    case command
    case insert
    case modifier
    case special
    
    init?(name: String?) {
        guard let n = name else { return nil }
        self.init(rawValue: n)
    }
}

enum EKModifierKey: String {
    case alt
    case command
    case control
    case meta
    case shift
    
    init?(name: String?) {
        guard let n = name else { return nil }
        self.init(rawValue: n)
    }
    
    var keyString: String {
        switch self {
        case .alt: return "A"
        case .command: return "D"
        case .control: return "C"
        case .meta: return "M"
        case .shift: return "S"
        }
    }
}

enum EKSpecialKey: String {
    case esc
    case up
    case down
    case left
    case right
    case tab
    
    init?(name: String?) {
        guard let n = name else { return nil }
        self.init(rawValue: n)
    }
}

protocol EKParseNode {
    init?(object: Any?) throws
}

// operation node
struct EKOperationInfo {
    let op: EKOperation
    let locations: EKLocationsInfo?
    let buttons: EKSubitems<EKButtonInfo>?
    let arguments: Any?
}

extension EKOperationInfo: EKParseNode {
    init?(object: Any?) throws {
        guard let d = object as? NodeDict else {
            throw EKError.info("invalid operation node: \(object ?? "nil")")
        }
        guard let op = EKOperation(name: d.anyValue(for: kOperation)) else {
            throw EKError.info("no valid operation for node: \(d)")
        }
        let locations = try EKLocationsInfo(object: d.anyValue(for: kLocations))
        let buttons = try EKSubitems<EKButtonInfo>(object: d.anyValue(for: kButtons))
        self.init(op: op,
                  locations: locations,
                  buttons: buttons,
                  arguments: d.anyValue(for: kArguments))
    }
}

extension EKOperationInfo {
    private static func operations(from object: Any?) throws -> [EKOperationInfo] {
        var result = [EKOperationInfo]()
        if let array = object as? NodeArray {
            result = try array.compactMap { try EKOperationInfo(object: $0) }
        } else if let op = try EKOperationInfo(object: object) {
            result.append(op)
        }
        
        return result
    }
    
    private static func parseArguments(_ arg: String) -> (subcmd: String?, arg: String) {
        var sc: String?
        let retarg: String
        if arg.isConfig {
            retarg = arg.trimmingCharacters(in: .whitespaces)
        } else if let r = arg.rangeOfCharacter(from: .whitespaces) {
            sc = String(arg[..<r.lowerBound])
            retarg = arg[r.upperBound...].trimmingCharacters(in: .whitespaces)
        } else {
            sc = arg.trimmingCharacters(in: .whitespaces)
            retarg = ""
        }
        
        return (sc, retarg)
    }
    
    static func operations(from cmdArg: String) throws -> [EKOperationInfo] {
        let (subcmd, arg) = self.parseArguments(cmdArg)
        let obj: Any?
        if let sc = subcmd { // operation as subcommand
            if arg.isConfigDict {
                guard var dict = object_of_expr(arg) as? NodeDict else {
                    throw EKError.info("invalid dict argument")
                }
                dict[kOperation] = sc
                obj = dict
            } else if arg.isConfigList {
                guard let list = object_of_expr(arg) as? NodeArray else {
                    throw EKError.info("invalid list argument")
                }
                let newList: [NodeDict]
                if let _ = list.first as? String { // strings list
                    newList = try list.map {
                        guard let s = $0 as? String else {
                            throw EKError.info("invalid argument in strings list")
                        }
                        return [kOperation: sc, kArguments: s]
                    }
                } else if let _ = list.first as? NodeDict { // dictionaries list
                    newList = try list.map {
                        guard var d = $0 as? NodeDict else {
                            throw EKError.info("invalid argument in dicts list")
                        }
                        d[kOperation] = sc
                        return d
                    }
                } else {
                    throw EKError.info("invalid list argument (string, dict)")
                }
                obj = newList
            } else { // string argument or none
                obj = [kOperation: sc, kArguments: arg]
            }
        } else { // configuration only
            obj = object_of_expr(arg)
        }
        
        return try self.operations(from: obj)
    }
}

// button node
struct EKButtonInfo: EKParseNode {
    let locations: EKLocationsInfo?
    let keys: EKSubitems<EKKeyInfo>?
}

extension EKButtonInfo {
    init?(object: Any?) throws {
        guard let d = object as? NodeDict else {
            throw EKError.info("invalid button node: \(object ?? "nil")")
        }
        let locs = try EKLocationsInfo(object: d.anyValue(for: kLocations))
        let keys = try EKSubitems<EKKeyInfo>(object: d.anyValue(for: kKeys))
        self.init(locations: locs, keys: keys)
    }
}

// key node
struct EKKeyInfo: EKParseNode {
    let type: EKKeyType
    let title: String
    let contents: String
}

extension EKKeyInfo {
    init?(object: Any?) throws {
        guard let d = object as? NodeDict else {
            throw EKError.info("invalid key node: \(object ?? "nil")")
        }
        guard let tp = EKKeyType(name: d.anyValue(for: kType)) else {
            throw EKError.info("no type for key: \(d)")
        }
        guard let tl: String = d.anyValue(for: kTitle), !tl.isEmpty else {
            throw EKError.info("no title for key: \(d)")
        }
        guard let cnt: String = d.anyValue(for: kContents), !cnt.isEmpty else {
            throw EKError.info("no contents for key: \(d)")
        }
        self.init(type: tp, title: tl, contents: cnt)
    }
}

// locations
struct EKLocationsInfo: EKParseNode {
    let locations: [Int]
}

extension EKLocationsInfo {
    init?(object: Any?) throws {
        if object == nil {
            return nil
        }
        guard let locs = object as? [Int] else {
            throw EKError.info("invalid locations \(object!)")
        }
        self.init(locations: locs)
    }
    
    subscript(_ i: Int) -> Int {
        return self.locations[i]
    }
}

// union-like subitems
struct EKSubitems<T: EKParseNode>: EKParseNode {
    let array: [T]?
    let dict: [Int: T]?
}

extension EKSubitems {
    init?(object: Any?) throws {
        var array: [T]? = nil
        var dict: [Int: T]? = nil
        if let a = object as? NodeArray {
            array = []
            for e in a {
                if let si = try T(object: e) {
                    array!.append(si)
                }
            }
        } else if let d = object as? NodeDict {
            dict = [:]
            for (k, o) in d {
                if let i = Int(k) {
                    dict![i] = try T(object: o)
                } else {
                    throw EKError.info("invalid location \"\(k)\"")
                }
            }
        }
        self.init(array: array, dict: dict)
    }
}

private extension Dictionary where Key: StringProtocol {
    func anyValue<T>(for key: Key) -> T? {
        return self[key] as? T
    }
}

private extension String {
    var isConfigDict: Bool {
        return self.hasPrefix("{")
    }
    
    var isConfigList: Bool {
        return self.hasPrefix("[")
    }
    
    var isConfig: Bool {
        return self.isConfigDict || self.isConfigList
    }
}
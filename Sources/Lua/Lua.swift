import CLua
import Foundation

public struct LuaError: Error, CustomStringConvertible {
    public let description: String
}

public enum MaybeFunction {
    case value(Function)
    case error(String)
}

public typealias ErrorHandler = (String) -> Void

public enum Type: Int32 {
    case string
    case number
    case boolean
    case function
    case table
    case userdata
    case lightUserdata
    case thread
    case `nil`
    case none
    
    public init?(rawValue: Int32) {
        switch rawValue {
        case LUA_TSTRING:
            self = .string
        case LUA_TNUMBER:
            self = .number
        case LUA_TBOOLEAN:
            self = .boolean
        case LUA_TFUNCTION:
            self = .function
        case LUA_TTABLE:
            self = .table
        case LUA_TUSERDATA:
            self = .userdata
        case LUA_TLIGHTUSERDATA:
            self = .lightUserdata
        case LUA_TTHREAD:
            self = .thread
        case LUA_TNIL:
            self = .nil
        case LUA_TNONE:
            self = .none
        default:
            return nil
        }
    }

    public var rawValue: Int32 {
        switch self {
        case .string:
            return LUA_TSTRING
        case .number:
            return LUA_TNUMBER
        case .boolean:
            return LUA_TBOOLEAN
        case .function:
            return LUA_TFUNCTION
        case .table:
            return LUA_TTABLE
        case .userdata:
            return LUA_TUSERDATA
        case .lightUserdata:
            return LUA_TLIGHTUSERDATA
        case .thread:
            return LUA_TTHREAD
        case .nil:
            return LUA_TNIL
        case .none:
            return LUA_TNONE
        }
    }
}

final class AnyType: Hashable {
    let type: Any.Type

    init(_ type: Any.Type) {
        self.type = type
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: type))
    }

    static func == (lhs: AnyType, rhs: AnyType) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

@dynamicMemberLookup
public class Lua {
    internal static let registryIndex = Int(CLUA_REGISTRYINDEX)
    private static let globalsTable = Int(LUA_RIDX_GLOBALS)
    let shouldCloseOnDeinit: Bool
    
    #warning("TODO: Use weak references here.")
    #warning("TODO: Deal with staticness here.")
    static var typeMap: [AnyType: (AnyKeyPath, Table, String)] = [:]
    
    internal let state: OpaquePointer!
    private var functions: [FunctionPointer] = []

    public init(loadStandardLibraries: Bool = true) {
        self.state = luaL_newstate()
        self.shouldCloseOnDeinit = true

        if loadStandardLibraries {
            self.loadStandardLibraries()
        }
    }
    
    init(_ state: OpaquePointer) {
        self.state = state
        self.shouldCloseOnDeinit = false
    }

    public func loadStandardLibraries() {
        luaL_openlibs(self.state)
    }

    deinit {
        guard self.shouldCloseOnDeinit else {
            return
        }
        
        lua_close(self.state)

        for function in self.functions {
            function.deallocate()
        }
    }

    public var globals: Table {
        self.rawGet(at: Self.registryIndex, n: Self.globalsTable)
        return self.pop(at: -1) as! Table
    }
    
    public subscript(dynamicMember member: String) -> Value {
        get {
            self.globals[member]
        }
        
        set {
            self.globals[member] = newValue
        }
    }
    
    public subscript<T: Value>(dynamicMember member: String) -> T {
        get {
            self.globals[member]
        }
        
        set {
            self.globals[member] = newValue
        }
    }
    
    public subscript<T: CustomTypeInstance>(dynamicMember member: String) -> T {
        get {
            self.globals[member]
        }
        
        set {
            self.globals[member] = newValue
        }
    }

    public var registry: Table {
        self.pushValue(at: Self.registryIndex)
        return self.pop(at: -1) as! Table
    }

    internal func function(_ body: String) throws -> Function {
        guard luaL_loadstring(self.state, body) == LUA_OK else {
            throw self.popError()
        }
        
        return self.pop(at: -1) as! Function
    }

    public func table(sequenceCapacity: Int = 0, keyCapacity: Int = 0) -> Table {
        lua_createtable(self.state, Int32(sequenceCapacity), Int32(keyCapacity))
        return self.pop(at: -1) as! Table
    }

    internal func popError() -> LuaError {
        LuaError(description: self.pop(at: -1) as! String)
    }



    @discardableResult
    public func evaluate(_ string: String, arguments: Value...) throws -> [Value] {
        return try evaluate(string, arguments: arguments)
    }
    
    @discardableResult
    public func evaluate(_ string: String, arguments: [Value]) throws -> [Value] {
        return try self.function(string).call(arguments)
    }

}

// MARK: Field

extension Lua {
    func register(type: Any.Type, keypath: AnyKeyPath, table: Table, key: String) {
        Self.typeMap[AnyType(type)] = (keypath, table, key)
    }
}

// MARK: Function

extension Lua {
    // Void return
    public func function(_ body: @escaping () throws -> Void) -> Function {
        let function = FunctionPointer { state in
            let lua = Lua(state)
            
            do {
                guard lua.topElementIndex == 0 else {
                    throw LuaError(description: "Invalid number of arguments. Expected 2, but got \(lua.topElementIndex).")
                }
                
                try body()
                return lua.push(values: [])
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        return self.create(function: function)
    }
    
    public func function<A: TypeCheckable>(_ body: @escaping (A) throws -> ()) -> Function {
        let function = FunctionPointer { state in
            let lua = Lua(state)
            
            do {
                guard lua.topElementIndex == 1 else {
                    throw LuaError(description: "Invalid number of arguments. Expected 2, but got \(lua.topElementIndex).")
                }
                
                let a: A = try lua.getParameter()
                try body(a)
                return lua.push(values: [])
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        return self.create(function: function)
    }
    
    public func function<A : TypeCheckable, B : TypeCheckable>(_ body: @escaping (A, B) throws -> Void) -> Function {
        let function = FunctionPointer { state in
            let lua = Lua(state)
            
            do {
                guard lua.topElementIndex == 2 else {
                    throw LuaError(description: "Invalid number of arguments. Expected 2, but got \(lua.topElementIndex).")
                }
                
                let a: A = try lua.getParameter()
                let b: B = try lua.getParameter()
                try body(a, b)
                return lua.push(values: [])
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        return self.create(function: function)
    }
    
    public func function<A : TypeCheckable, B : TypeCheckable, C : TypeCheckable>(_ body: @escaping (A, B, C) throws -> Void) -> Function {
        let function = FunctionPointer { state in
            let lua = Lua(state)
            
            do {
                guard lua.topElementIndex == 3 else {
                    throw LuaError(description: "Invalid number of arguments. Expected 2, but got \(lua.topElementIndex).")
                }
                
                let a: A = try lua.getParameter()
                let b: B = try lua.getParameter()
                let c: C = try lua.getParameter()
                try body(a, b, c)
                return lua.push(values: [])
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        return self.create(function: function)
    }
    
    // Single-value return
    
    public func function(_ body: @escaping () throws -> Value) -> Function {
        let function = FunctionPointer { state in
            let lua = Lua(state)
            
            do {
                guard lua.topElementIndex == 0 else {
                    throw LuaError(description: "Invalid number of arguments. Expected 2, but got \(lua.topElementIndex).")
                }
                
                let result = try body()
                return lua.push(values: [result])
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        return self.create(function: function)
    }

    public func function<A: TypeCheckable>(_ body: @escaping (A) throws -> Value) -> Function {
        let function = FunctionPointer { state in
            let lua = Lua(state)
            
            do {
                guard lua.topElementIndex == 1 else {
                    throw LuaError(description: "Invalid number of arguments. Expected 2, but got \(lua.topElementIndex).")
                }
                
                let a: A = try lua.getParameter()
                let result = try body(a)
                return lua.push(values: [result])
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        return self.create(function: function)
    }
    
    public func function<A : TypeCheckable, B : TypeCheckable>(_ body: @escaping (A, B) throws -> Value) -> Function {
        let function = FunctionPointer { state in
            let lua = Lua(state)
            
            do {
                guard lua.topElementIndex == 2 else {
                    throw LuaError(description: "Invalid number of arguments. Expected 2, but got \(lua.topElementIndex).")
                }
                
                let a: A = try lua.getParameter()
                let b: B = try lua.getParameter()
                let value = try body(a, b)
                return lua.push(values: [value])
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        return self.create(function: function)
    }
    
    public func function<A : TypeCheckable, B : TypeCheckable, C : TypeCheckable>(_ body: @escaping (A, B, C) throws -> Value) -> Function {
        let function = FunctionPointer { state in
            let lua = Lua(state)
            
            do {
                guard lua.topElementIndex == 3 else {
                    throw LuaError(description: "Invalid number of arguments. Expected 2, but got \(lua.topElementIndex).")
                }
                
                let a: A = try lua.getParameter()
                let b: B = try lua.getParameter()
                let c: C = try lua.getParameter()
                let result = try body(a, b, c)
                return lua.push(values: [result])
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        return self.create(function: function)
    }
    
    // Custom-type return
    
    public func function<U: CustomTypeInstance>(_ body: @escaping () throws -> U) -> Function {
        let function = FunctionPointer { state in
            let lua = Lua(state)
            
            do {
                guard lua.topElementIndex == 0 else {
                    throw LuaError(description: "Invalid number of arguments. Expected 2, but got \(lua.topElementIndex).")
                }
                
                let result = try lua.userdata(body())
                return lua.push(values: [result])
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        return self.create(function: function)
    }
    
    public func function<A: Value, U: CustomTypeInstance>(_ body: @escaping (A) throws -> U) -> Function {
        let function = FunctionPointer { state in
            let lua = Lua(state)
            
            do {
                guard lua.topElementIndex == 1 else {
                    throw LuaError(description: "Invalid number of arguments. Expected 2, but got \(lua.topElementIndex).")
                }
                
                let a: A = try lua.getParameter()
                let result = try lua.userdata(body(a))
                return lua.push(values: [result])
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        return self.create(function: function)
    }
    
    // Array return
    
    public func function(_ body: @escaping () throws -> [Value]) -> Function {
        let function = FunctionPointer { state in
            let lua = Lua(state)
            
            do {
                guard lua.topElementIndex == 0 else {
                    throw LuaError(description: "Invalid number of arguments. Expected 2, but got \(lua.topElementIndex).")
                }
                
                let array = try body()
                
                #warning("Create overload for table that takes an array")
                let table = lua.table()
                
                for (i, element) in array.enumerated() {
                    table[i + 1] = element
                }
    
                return lua.push(values: [table])
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        return self.create(function: function)
    }

    public func function<A: TypeCheckable>(_ body: @escaping (A) throws -> [Value]) -> Function {
        let function = FunctionPointer { state in
            let lua = Lua(state)
            
            do {
                guard lua.topElementIndex == 1 else {
                    throw LuaError(description: "Invalid number of arguments. Expected 2, but got \(lua.topElementIndex).")
                }
                
                let a: A = try lua.getParameter()
                let array = try body(a)
                
                #warning("Create overload for table that takes an array")
                let table = lua.table()
                
                for (i, element) in array.enumerated() {
                    table[i + 1] = element
                }
    
                return lua.push(values: [table])
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        return self.create(function: function)
    }
    
    public func function<A : TypeCheckable, B : TypeCheckable>(_ body: @escaping (A, B) throws -> [Value]) -> Function {
        let function = FunctionPointer { state in
            let lua = Lua(state)
            
            do {
                guard lua.topElementIndex == 2 else {
                    throw LuaError(description: "Invalid number of arguments. Expected 2, but got \(lua.topElementIndex).")
                }
                
                let a: A = try lua.getParameter()
                let b: B = try lua.getParameter()
                let array = try body(a, b)
                
                #warning("Create overload for table that takes an array")
                let table = lua.table()
                
                for (i, element) in array.enumerated() {
                    table[i + 1] = element
                }
    
                return lua.push(values: [table])
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        return self.create(function: function)
    }
    
    public func function<A: TypeCheckable, B: TypeCheckable, C: TypeCheckable>(_ body: @escaping (A, B, C) throws -> [Value]) -> Function {
        let function = FunctionPointer { state in
            let lua = Lua(state)
            
            do {
                guard lua.topElementIndex == 3 else {
                    throw LuaError(description: "Invalid number of arguments. Expected 2, but got \(lua.topElementIndex).")
                }
                
                let a: A = try lua.getParameter()
                let b: B = try lua.getParameter()
                let c: C = try lua.getParameter()
                let array = try body(a, b, c)
                
                #warning("Create overload for table that takes an array")
                let table = lua.table()
                
                for (i, element) in array.enumerated() {
                    table[i + 1] = element
                }
    
                return lua.push(values: [table])
            } catch {
                lua.push(error: error)
                return 0
            }
        }

        return self.create(function: function)
    }
    
    #warning("TODO: Create functions that return tuples")
    #warning("TODO: Create functions that return dictionaries")
    #warning("TODO: Create functions that receive and return variadics")

    private func create(function: FunctionPointer) -> Function {
        let cClosure: @convention(c) (OpaquePointer?) -> Int32 = { state in
            lua_touserdata(
                state!, 
                lua_getupvalueindex(1)
            )!
            .assumingMemoryBound(to: FunctionPointer.Function.self)
            .pointee(state!)
        }
       
        self.functions.append(function)
        lua_pushlightuserdata(self.state, function.pointer)
        lua_pushcclosure(self.state, cClosure, 1)
        return self.pop(at: -1) as! Function
    }
    
    private func getParameter<T: TypeCheckable>() throws -> T {
        guard let value = self.pop(at: 1) else {
            throw LuaError(description: "No value: Expected value of type \(String(reflecting: T.self)) but got no value instead.")
        }

        if !T.typecheck(value: value, lua: self) {
            throw LuaError(description: "Unexpected type: Expected value of type \(String(reflecting: T.self)) but got value of type \(String(reflecting: type(of: value))) instead.")
        }

        if let a = value as? T {
            return a
        } else if let userdata = value as? Userdata, T.self is CustomTypeInstance.Type {
            return userdata.forceToCustomType()
        } else {
            throw LuaError(description: "Invalid value: Value not convertible to \(String(reflecting: T.self)).")
        }
    }

    private func push(values: [Value]) -> Int32  {
        for value in values {
            value.push(self)
        }

        return Int32(values.count)
    }

    private func push(error: Error) {
        String(describing: error).push(self)
        lua_error(self.state)
    }
}

// MARK: Table

extension Lua {
    public func table<T: CustomTypeInstance>(of type: T.Type) -> CustomType<T> {
        self.create(tableOf: type)
    }
    
    public func table<T>(of type: T.Type) -> CustomType<T> where T: CustomTypeInstance & Equatable {
        let customType = self.create(tableOf: type)

        customType["__eq"] = self.function { (lhs: Userdata, rhs: Userdata) -> Bool in
            let lhs: T = lhs.toCustomType()
            let rhs: T = rhs.toCustomType()
            return lhs == rhs
        }

        return customType
    }
    
    private func create<T: CustomTypeInstance>(tableOf type: T.Type) -> CustomType<T> {
        lua_createtable(self.state, 0, 0)
        let customType = CustomType<T>(self.state)
        self.pop()

        self.registry[T.luaTypeName] = customType
        customType.becomeMetatableFor(customType)
        customType["__index"] = customType
        customType["__name"] = T.luaTypeName

        customType["__gc"] = self.function { (userdata: Userdata) -> Void in
            let instance: T = userdata.toCustomType()
            instance.deinitialize()
            (userdata.userdataPointer() as UnsafeMutablePointer<T>)
                .deinitialize(count: 1)
        }
        
        return customType
    }
    
    func userdata<T: CustomTypeInstance>(_ customType: T) -> Userdata {
        let userdataPointer = lua_newuserdata(self.state, MemoryLayout<T>.size)!
        // this both pushes pointer onto stack and returns it
        let boundUserdataPointer = userdataPointer.assumingMemoryBound(to: T.self)
        // creates a new legit reference to customType
        boundUserdataPointer.initialize(to: customType)
        // this requires pointer to be on the stack
        luaL_setmetatable(self.state, T.luaTypeName)
        // this pops pointer off stack
        return self.pop(at: -1) as! Userdata
    }
}

// MARK: Internal

extension Lua {
    func pop(at index: Int) -> Value? {
        self.moveToTopValue(at: index)
        var value: Value?
        
        switch Type(rawValue: lua_type(self.state, Int32(-1))) {
        case .string:
            var length: Int = 0
            let string = lua_tolstring(self.state, -1, &length)
            let data = Data(bytes: string!, count: Int(length))
            value = String(data: data, encoding: String.Encoding.utf8)
        case .number:
            #warning("TODO: Return proper Double or Int")
            value = Number(self.state)
        case .boolean:
            value = lua_toboolean(self.state, -1) == 1 ? true : false
        case .function:
            value = Function(self.state)
        case .table:
            value = Table(self.state)
        case .userdata:
            value = Userdata(self.state)
        case .lightUserdata:
            value = LightUserdata(self.state)
        case .thread:
            value = Thread(self.state)
        case .nil:
            #warning("TODO: Use Optional to model this")
            value = Nil()
        default:
            break
        }
        
        self.pop()
        return value
    }
    
    func moveToTopValue(at index: Int) {
        var index = index

        if index == -1 || index == self.topElementIndex {
            return
        }

        index = self.absolute(index: index)
        self.pushValue(at: index)
        self.remove(at: index)
    }

    func reference(_ position: Int) -> Int {
        Int(luaL_ref(self.state, Int32(position)))
    }

    func releaseReference(_ table: Int, _ position: Int) {
        luaL_unref(self.state, Int32(table), Int32(position))
    }

    func absolute(index: Int) -> Int {
        Int(lua_absindex(self.state, Int32(index)))
    }

    func rawGet(at index: Int, n: Int) {
        lua_rawgeti(self.state, Int32(index), lua_Integer(n))
    }

    func pushValue(at index: Int) {
        lua_pushvalue(self.state, Int32(index))
    }

    func pop(n: Int = 1) {
        lua_settop(self.state, -Int32(n)-1)
    }

    func rotate(at index: Int, n: Int) {
        lua_rotate(self.state, Int32(index), Int32(n))
    }

    func remove(at index: Int) {
        self.rotate(at: index, n: -1)
        self.pop()
    }

    var topElementIndex: Int {
        Int(lua_gettop(self.state))
    }
}

fileprivate struct FunctionPointer {
    fileprivate typealias Function = (OpaquePointer) -> Int32
    fileprivate let pointer: UnsafeMutablePointer<Function>

    fileprivate init(_ function: @escaping Function) {
        self.pointer = UnsafeMutablePointer<Function>
            .allocate(capacity: 1)
        self.pointer
            .initialize(to: function)
    }

    fileprivate func deallocate() {
        self.pointer
            .deinitialize(count: 1)
            .deallocate()
    }
}


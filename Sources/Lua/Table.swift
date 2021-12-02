import CLua

public class Table: StoredValue {
    public override var type: Type {
        .table
    }

    public override class func typecheck(value: Value, lua: Lua) -> Bool {
        value.type == .table
    }
    
    public subscript<U: Value>(key: Value, as type: U.Type = U.self) -> U {
        self[key] as! U
    }
    
    public subscript<U: CustomTypeInstance>(key: Value, as type: U.Type = U.self) -> U {
        let instance: U = (self[key] as! Userdata).toCustomType()
        
        #warning("TODO: Deal with staticness here.")
        print(Lua.typeMap)
        if
            let (keypath, table, key) = Lua.typeMap[AnyType(type)],
            let field = instance[keyPath: keypath] as? FieldBindable
        {
            field.bind(table: table, key: key)
        }
        
        return instance
    }

    public subscript(key: Value) -> Value {
        get {
            self.push(self.lua)
            key.push(self.lua)
            lua_gettable(self.lua.state, -2)
            let value = self.lua.pop(at: -1)
            self.lua.pop()
            return value!
        }

        set {
            self.push(self.lua)
            key.push(self.lua)
            newValue.push(self.lua)
            lua_settable(self.lua.state, -3)
            self.lua.pop()
        }
    }
    
    // Array return

    public func function(_ name: String, _ body: @escaping () -> [Value]) -> Self {
        self[name] = self.lua.function(body)
        return self
    }

    public func function<A: Value>(_ name: String, _ body: @escaping (A) -> [Value]) -> Self {
        self[name] = self.lua.function(body)
        return self
    }

    public func function<A: Value, B: Value>(_ name: String, _ body: @escaping (A, B) -> [Value]) -> Self {
        self[name] = self.lua.function(body)
        return self
    }
    
    public func function<A: Value, B: Value, C: Value>(_ name: String, _ body: @escaping (A, B, C) -> [Value]) -> Self {
        self[name] = self.lua.function(body)
        return self
    }
    
    // Custom-type return
    
    public func function<U: CustomTypeInstance>(_ name: String, _ body: @escaping () -> U) -> Self {
        #warning("TODO: Move this to Lua and just call from here")
        self[name] = self.lua.function(body)
        return self
    }
    
    public func function<A: Value, U: CustomTypeInstance>(_ name: String, _ body: @escaping (A) -> U) -> Self {
        #warning("TODO: Move this to Lua and just call from here")
        self[name] = self.lua.function(body)
        return self
    }

    public func keys() -> [Value] {
        var keys = [Value]()
        self.push(self.lua) // table
        lua_pushnil(self.lua.state)
        
        while lua_next(self.lua.state, -2) != 0 {
            self.lua.pop() // val
            let key = self.lua.pop(at: -1)!
            keys.append(key)
            key.push(self.lua)
        }
        
        self.lua.pop() // table
        return keys
    }

    public func becomeMetatableFor(_ value: Value) {
        value.push(self.lua)
        self.push(self.lua)
        lua_setmetatable(self.lua.state, -2)
        self.lua.pop()
    }

    public func asTupleArray<K1: Value, V1: Value, K2: Value, V2: Value>(
        _ mapKey: (K1) -> K2 = { $0 as! K2 },
        _ mapValue: (V1) -> V2 = { $0 as! V2 }
    ) -> [(K2, V2)] {
        var tupleArray: [(K2, V2)] = []
        
        for key in self.keys() {
            let value = self[key]
            
            if key is K1 && value is V1 {
                tupleArray.append((mapKey(key as! K1), mapValue(value as! V1)))
            }
        }
        
        return tupleArray
    }

    public func asDictionary<K1: Value, V1: Value, K2: Value, V2: Value>(
        _ mapKey: (K1) -> K2 = {$0 as! K2},
        _ mapValue: (V1) -> V2 = {$0 as! V2}
    ) -> [K2: V2] where K2: Hashable {
        var dictionary: [K2: V2] = [:]
        
        for (key, val) in self.asTupleArray(mapKey, mapValue) {
            dictionary[key] = val
        }
        
        return dictionary
    }

    public func asArray<T: Value>() -> [T] {
        var sequence: [T] = []

        let dictionary: [Int64: T] = self.asDictionary(
            { (key: Number) in key.toInteger() },
            { $0 as T }
        )

        guard !dictionary.isEmpty else {
            return sequence
        }

        // ensure table has no holes and keys start at 1
        let sortedKeys = dictionary.keys.sorted()
        
        guard [Int64](1...sortedKeys.last!) == sortedKeys else {
            return sequence
        }

        // append values to the array, in order
        for i in sortedKeys {
            sequence.append(dictionary[i]!)
        }

        return sequence
    }
}

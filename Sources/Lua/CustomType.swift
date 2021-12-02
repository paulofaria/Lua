protocol FieldBindable {
    func bind(table: Table, key: Value)
}

@propertyWrapper
public class Field<T: Value>: FieldBindable {
    enum Storage {
        case unbound(T)
        case bound(table: Table, key: Value)
    }
    
    var storage: Storage
    
    public var wrappedValue: T {
        get {
            switch self.storage {
            case let .unbound(value):
                return value
            case let .bound(table: table, key: key):
                return table[key]
            }
        }
        
        set {
            switch self.storage {
            case .unbound:
                self.storage = .unbound(newValue)
            case let .bound(table: table, key: key):
                table[key] = newValue
            }
        }
    }
    
    public init(wrappedValue: T) {
        self.storage = .unbound(wrappedValue)
    }
    
    public var projectedValue: Field<T> {
        self
    }
    
    func bind(table: Table, key: Value) {
        if case let .unbound(previousValue) = self.storage {
            table[key] = previousValue
        }
        
        self.storage = .bound(table: table, key: key)
    }
}

public class CustomType<T: CustomTypeInstance>: Table {
    #warning("TODO: Rename name property to key.")
    public func field<U: Value>(_ key: String, _ keypath: KeyPath<T, Field<U>>) -> Self {
        self.lua.register(type: T.self, keypath: keypath, table: self, key: key)
        #warning("Create AnyValue type eraser and erase previousIndex and make it unowned. Also use AnyValue for key parameter.")
        return self
    }
    
    // Void return
    
    public func method(_ name: String, _ body: @escaping (T) -> () -> Void) -> Self {
        self[name] = self.lua.function { (t: T) in
            body(t)()
        }
        
        return self
    }

    public func method<A: Value>(_ name: String, _ body: @escaping (T) -> (A) -> Void) -> Self {
        self[name] = self.lua.function { (t: T, a: A) -> Void in
            body(t)(a)
        }
        
        return self
    }

    public func method<A: Value, B: Value>(_ name: String, _ body: @escaping (T) -> (A, B) -> Void) -> Self {
        self[name] = self.lua.function { (t: T, a: A, b: B) -> Void in
            body(t)(a,b)
        }
        
        return self
    }
    
    // Single value return
    
    public func method<U: Value>(_ name: String, _ body: @escaping (T) -> () -> U) -> Self {
        self[name] = self.lua.function { t in
            body(t)()
        }
        
        return self
    }

    public func method<A: Value, U: Value>(_ name: String, _ body: @escaping (T) -> (A) -> U) -> Self {
        self[name] = self.lua.function { t, a in
            body(t)(a)
        }
        
        return self
    }

    public func method<A: Value, B: Value, U: Value>(_ name: String, _ body: @escaping (T) -> (A, B) -> U) -> Self {
        self[name] = self.lua.function { t, a, b in
            body(t)(a,b)
        }
        
        return self
    }
}

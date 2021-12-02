public class LightUserdata: StoredValue {
    override public var type: Type {
        return .lightUserdata
    }

    override public class func typecheck(value: Value, lua: Lua) -> Bool {
        return value.type == .lightUserdata
    }
}

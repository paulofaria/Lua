public protocol Value: TypeCheckable {
    func push(_ lua: Lua)
    var type: Type { get }
}

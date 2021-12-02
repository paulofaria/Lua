import XCTest
@testable import Lua

#warning("TODO: Map an array to a table in lua")
func split(subject: String, separator: String) -> [String] {
    subject.components(separatedBy: separator)
}

struct SomeError: Error, CustomStringConvertible {
    var description: String
}

#warning("TODO: Model throws returning two values with nil first and second value as error message")
func throwing(shouldThrow: Bool) throws -> String {
    if shouldThrow {
        return "Success"
    } else {
        throw SomeError(description: "Failure")
    }
}


final class Note: Equatable {
    @Field
    var name: String
    
    init(name: String) {
        self.name = name
    }
    
    func setName(name: String) {
        self.name = name
    }
    
    func getName() -> String {
        self.name
    }
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.name == rhs.name
    }
}

extension Note: CustomTypeInstance {}

class LuaTests : XCTestCase {
    func testCreateTable() throws {
        let lua = Lua()
        let table = lua.table()
        table[3] = "foo"
        XCTAssert(table[3] is String)
        XCTAssertEqual(table[3] as! String, "foo")
    }
    
    func testCallLuaFunctionFromSwift() throws {
        let lua = Lua()
        
        try lua.evaluate(
            """
            function split(subject, separator)
              local t = {}
            
              for word in string.gmatch(subject, "([^"..separator.."]+)") do
                table.insert(t, word)
              end
            
              return t
            end
            """
        )
        
        let split: Function = lua.globals["split"]
        let values = try split.call("hello world", " ")
        
        XCTAssertEqual(values.count, 1)
        XCTAssert(values[0] is Table)
        #warning("TODO: improve this API")
        let array: [String] = (values[0] as! Table).asArray()
        XCTAssertEqual(array, ["hello", "world"])
    }
    
    func testCallSwiftFunctionFromLua() throws {
        let lua = Lua()
        lua.globals["split"] = lua.function(split)
        let values = try lua.evaluate("return split('hello world', ' ')")

        XCTAssertEqual(values.count, 1)
        XCTAssert(values[0] is Table)
        #warning("TODO: improve this API")
        let array: [String] = (values[0] as! Table).asArray()
        XCTAssertEqual(array, ["hello", "world"])
    }

    func testCustomType() throws {
        let lua = Lua()

        #warning("Add property to table")
        lua.globals["note"] = lua.table(of: Note.self)
            .function("new", Note.init)
            .field("name", \.$name)
            .method("getName", Note.getName)
            .method("setName", Note.setName)
            
        try lua.evaluate("noteA = note.new('Note A')")
        let noteA: Note = lua.globals["noteA"]
        XCTAssertEqual(noteA.name, "Note A")
        
        noteA.name = "yo"
        let yo = try lua.evaluate("return noteA.name")
        print(yo)

        noteA.name = "Note A*"
        try lua.evaluate("print(noteA:getName())")

        try lua.evaluate("noteA:setName('Note A**')")
        XCTAssertEqual(noteA.name, "Note A**")

        try lua.evaluate("noteA:setName('Note A***')")
        XCTAssertEqual(noteA.name, "Note A***")
        
        var checkNoteCalled = false
        
        func checkNote(_ note: Note) {
            checkNoteCalled = true
            XCTAssertTrue(noteA === note)
        }
        
        lua.globals["checkNote"] = lua.function(checkNote)
        try lua.evaluate("checkNote(noteA)")
        XCTAssertTrue(checkNoteCalled)
        
        try lua.evaluate("noteB = note.new('Note B')")
        var isEqual = try lua.evaluate("return noteA == noteB")[0] as! Bool
        XCTAssertFalse(isEqual)
        
        let noteB: Note = lua.globals["noteB"]
        noteA.name = "Note C"
        noteB.name = "Note C"
        
        isEqual = try lua.evaluate("return noteA == noteB")[0] as! Bool
        XCTAssertTrue(isEqual)
    }
    
//    func testAPI() {
//        let lua = Lua()
//
//        lua.globals["note"] = lua.table(of: Note.self) {
//            function("new", Note.init)
//            method("setName", Note.setName)
//            method("getName", Note.getName)
//        }
//    }
}

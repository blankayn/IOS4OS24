import Foundation

struct CalculatorEngine {
    private(set) var display = "0"
    private var accumulator: Double?
    private var operation: String?
    private var fresh = true
    private var repeatOperation: String?
    private var repeatOperand: Double?

    mutating func press(_ key: String) {
        if key == "AC" { self = CalculatorEngine(); return }
        if display == "Error" { self = CalculatorEngine() }
        if "0123456789".contains(key), key.count == 1 {
            if fresh || display == "0" { display = key; fresh = false }
            else if display.count < 12 { display += key }
            return
        }
        if key == "." {
            if fresh { display = "0"; fresh = false }
            if !display.contains(".") { display += "." }
            return
        }
        guard let number = Double(display) else { return }
        if key == "±" { display = format(-number); return }
        if key == "%" { display = format(number / 100); return }
        if ["+", "−", "×", "÷"].contains(key) {
            if !fresh, let old = accumulator, let op = operation {
                let result = calculate(old, number, op)
                guard result.isFinite else { fail(); return }
                accumulator = result; display = format(result)
            } else if accumulator == nil { accumulator = number }
            operation = key; fresh = true; repeatOperation = nil; repeatOperand = nil
        } else if key == "=" {
            let lhs = accumulator ?? number
            let rhs = operation == nil ? (repeatOperand ?? number) : number
            guard let op = operation ?? repeatOperation else { return }
            let result = calculate(lhs, rhs, op)
            guard result.isFinite else { fail(); return }
            display = format(result); accumulator = nil
            repeatOperation = op; repeatOperand = rhs; operation = nil; fresh = true
        }
    }
    private func calculate(_ left: Double, _ right: Double, _ op: String) -> Double {
        switch op { case "+": return left + right; case "−": return left - right; case "×": return left * right; default: return right == 0 ? .nan : left / right }
    }
    private func format(_ value: Double) -> String { return value == 0 ? "0" : String(format: "%.9g", value) }
    private mutating func fail() { display = "Error"; accumulator = nil; operation = nil; repeatOperation = nil; repeatOperand = nil; fresh = true }
}

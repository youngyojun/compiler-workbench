module {
  func.func @mul_one(%x: i32) -> i32 {
    %one = arith.constant 1 : i32
    %y = arith.muli %x, %one : i32
    return %y : i32
  }
}

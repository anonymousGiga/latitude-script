use revm_utils::time_utils::instant::Instant;
fn main() {
    const TIMES: u64 = 1_000_000;
    let start = Instant::now();
    for _ in 0..TIMES {
        let _a = Instant::now();
    }
    let now = Instant::now();
    let ns = now.checked_nanos_since(start).expect("overflow");
    println!("overhead = {:?}", ns / TIMES as f64);
}

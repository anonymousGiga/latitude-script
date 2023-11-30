use revm_utils::time_utils::instant::Instant;
use minstant::Instant as minInstant;
const TIMES: u64 = 1_000_000;
fn main() {
    test_rdtsc();
    test_minstant();
}

fn test_rdtsc() {
    let start = Instant::now();
    for _ in 0..TIMES {
        let _a = Instant::now();
    }
    let now = Instant::now();
    let ns = now.checked_nanos_since(start).expect("overflow");
    println!("rdtsc overhead = {:?}", ns / TIMES as f64);
}

fn test_minstant() {
    let start = minInstant::now();
    for _ in 0..TIMES {
        let _a = minInstant::now();
    }
    let now = minInstant::now();
    let ns = now.checked_duration_since(start).expect("overflow").as_nanos();
    println!("minstant overhead = {:?}", ns as f64 / TIMES as f64);

}
pub mod erc20;
pub mod keys;
// pub mod keys_types;
// pub mod defi_types;
// // pub mod types;
// pub mod defi_types;
pub mod types {
    pub mod defi_types;
    pub mod keys_types;
}

pub mod tokens {
    // mod defi_types;
    mod jbtc;
}

pub mod defi {
    // mod defi_types;
    mod vault;
}

fn main() -> u32 {
    fib(16)
}

fn fib(mut n: u32) -> u32 {
    let mut a: u32 = 0;
    let mut b: u32 = 1;
    while n != 0 {
        n = n - 1;
        let temp = b;
        b = a + b;
        a = temp;
    };
    a
}


/// Module containing tests.
mod tests {
    #[cfg(test)]
    mod test_keys;
}

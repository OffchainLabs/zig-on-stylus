use ethers::{
    providers::{Http, Provider},
    types::{transaction::eip2718::TypedTransaction, Address, Eip1559TransactionRequest},
};
use std::time::Instant;

#[tokio::main]
async fn main() -> eyre::Result<()> {
    let program_address = "2aa980ae2a062530984281927a4ff2a9672b71c3".to_string();
    let rpc_url = "https://stylus-testnet.arbitrum.io/rpc";

    let provider = Provider::<Http>::try_from(rpc_url)?;
    let address: Address = program_address.parse()?;

    let checks: Vec<(u16, bool)> = vec![
        (2, true),
        (3, true),
        (4, false),
        (5, true),
        (6, false),
        (32, false),
        (53, true),
    ];
    for (num_to_check, is_prime) in checks {
        let tx_req = Eip1559TransactionRequest::new()
            .to(address)
            .data(num_to_check.to_le_bytes());
        let tx = TypedTransaction::Eip1559(tx_req);
        let start = Instant::now();
        let got = provider.call_raw(&tx).await?;
        let end = Instant::now();
        println!("Resp: {:?}, took: {:?}", got[0], end.duration_since(start));
        assert!(is_prime as u8 == got[0]);
    }
    Ok(())
}

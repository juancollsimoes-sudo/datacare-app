pub fn start_local_server(port: u16) {
    std::thread::spawn(move || {
        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(async {
            crate::server::start_server(port).await;
        });
    });
}

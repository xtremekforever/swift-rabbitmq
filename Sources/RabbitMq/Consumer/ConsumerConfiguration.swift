struct ConsumerConfiguration {
    let queueName: String
    let exchangeName: String
    let routingKey: String
    let exchangeOptions: ExchangeOptions
    let queueOptions: QueueOptions
    let bindingOptions: BindingOptions
    let consumerOptions: ConsumerOptions
}

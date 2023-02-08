using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using OrderPrcoessor.Common;
using OrderProcessor.Services.Interfaces;

namespace OrderProcessor.Services
{
    public class OrderRepository : IOrderRepository
    {
        private readonly ILogger<OrderRepository> _logger;
        private readonly IConfiguration _configuration;
        private readonly CosmosClient _cosmosClient;
        private readonly Container _container;
        private readonly ServiceBusClient _serviceBusClient;

        public OrderRepository(ILogger<OrderRepository> logger, IConfiguration configuration, CosmosClient cosmosClient, ServiceBusClient serviceBusClient)
        {
            _logger=logger;
            _configuration=configuration;
            _cosmosClient=cosmosClient;
            _serviceBusClient=serviceBusClient;
            _container = _cosmosClient.GetContainer(_configuration["DatabaseName"], _configuration["ContainerName"]);
        }

        public async Task SaveOrderMessage(Order order)
        {
            try
            {
                ItemRequestOptions itemRequestOptions = new ItemRequestOptions
                {
                    EnableContentResponseOnWrite = false
                };

                await _container.CreateItemAsync(order, new PartitionKey(order.Id), itemRequestOptions);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Exception thrown in {nameof(SaveOrderMessage)}: {ex.Message}");
                throw;
            }
        }

        public async Task SendOrderMessage(Order order)
        {
            try
            {
                ServiceBusSender serviceBusSender = _serviceBusClient.CreateSender(_configuration["QueueName"]);
                var message = JsonConvert.SerializeObject(order);
                await serviceBusSender.SendMessageAsync(new ServiceBusMessage(message));
            }
            catch (Exception ex)
            {
                _logger.LogError($"Exception thrown in {nameof(SendOrderMessage)}: {ex.Message}");
                throw;
            }
        }
    }
}

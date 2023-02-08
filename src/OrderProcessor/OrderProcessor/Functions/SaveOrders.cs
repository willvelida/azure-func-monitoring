using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using OrderPrcoessor.Common;
using OrderProcessor.Services.Interfaces;

namespace OrderProcessor.Functions
{
    public class SaveOrders
    {
        private readonly ILogger<SaveOrders> _logger;
        private readonly IOrderRepository _orderRepository;

        public SaveOrders(ILogger<SaveOrders> logger, IOrderRepository orderRepository)
        {
            _logger=logger;
            _orderRepository=orderRepository;
        }


        [Function(nameof(SaveOrders))]
        public async Task Run([ServiceBusTrigger("orders", Connection = "ServiceBusConnection")] string myQueueItem)
        {
            try
            {
                _logger.LogInformation("Attempting to parse Order message");
                var order = JsonConvert.DeserializeObject<Order>(myQueueItem);

                _logger.LogInformation($"Saving OrderId: {order.Id} to the database");
                await _orderRepository.SaveOrderMessage(order);
                _logger.LogInformation($"OrderId: {order.Id} saved");
            }
            catch (Exception ex)
            {
                _logger.LogError($"Exception thrown in {nameof(SaveOrders)}: {ex.Message}");
                throw;
            }
        }
    }
}

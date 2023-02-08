using Bogus;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using OrderPrcoessor.Common;
using OrderProcessor.Services.Interfaces;

namespace OrderProcessor.Functions
{
    public class SendOrders
    {
        private readonly ILogger<SendOrders> _logger;
        private readonly IOrderRepository _orderRepository;

        public SendOrders(ILogger<SendOrders> logger, IOrderRepository orderRepository)
        {
            _logger=logger;
            _orderRepository=orderRepository;
        }

        [Function(nameof(SendOrders))]
        public async Task<IActionResult> Run([HttpTrigger(AuthorizationLevel.Anonymous, "get")] HttpRequestData req)
        {
            IActionResult result;

            try
            {
                _logger.LogInformation($"Creating Orders");
                var orders = new Faker<Order>()
                    .RuleFor(o => o.Id, (fake) => Guid.NewGuid().ToString())
                    .RuleFor(o => o.ProductName, (fake) => fake.Commerce.ProductName())
                    .RuleFor(o => o.Price, (fake) => fake.Random.Double(9.99, 19.99))
                    .Generate(100);

                _logger.LogInformation($"Sending {orders.Count} to service bus");
                foreach (var order in orders)
                {
                    _logger.LogInformation($"Sending {order.Id}");
                    await _orderRepository.SendOrderMessage(order);
                    _logger.LogInformation($"Order sent. Details: OrderId: {order.Id} | ProductName: {order.ProductName} | Price: {order.Price}");
                }

                result = new OkResult();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Exception thrown in {nameof(SendOrders)}: {ex.Message}");
                result = new StatusCodeResult(StatusCodes.Status500InternalServerError);
            }

            return result;
        }
    }
}

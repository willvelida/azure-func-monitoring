using OrderPrcoessor.Common;

namespace OrderProcessor.Services.Interfaces
{
    public interface IOrderRepository
    {
        Task SendOrderMessage(Order order);
        Task SaveOrderMessage(Order order);
    }
}

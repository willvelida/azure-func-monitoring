using Newtonsoft.Json;

namespace OrderPrcoessor.Common
{
    public class Order
    {
        [JsonProperty("id")]
        public string Id { get; set; }
        public string ProductName { get; set; }
        public double Price { get; set; }
    }
}
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using OrderProcessor.Services;
using OrderProcessor.Services.Interfaces;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureAppConfiguration(config =>
    {
        config.SetBasePath(Directory.GetCurrentDirectory())
            .AddEnvironmentVariables();
    })
    .ConfigureServices(s =>
    {
        s.AddLogging();
        s.AddSingleton(sp =>
        {
            IConfiguration configuration = sp.GetService<IConfiguration>();
            return new ServiceBusClient(configuration["ServiceBusEndpoint"], new DefaultAzureCredential());
        });
        s.AddSingleton(sp =>
        {
            IConfiguration configuration = sp.GetService<IConfiguration>();
            return new CosmosClient(configuration["CosmosDbEndpoint"], new DefaultAzureCredential());
        });
        s.AddTransient<IOrderRepository, OrderRepository>();
    })
    .Build();

host.Run();

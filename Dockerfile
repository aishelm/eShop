# Use the .NET 9.0 SDK image for building
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

# Install required dependencies for gRPC tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    protobuf-compiler \
    libprotobuf-dev \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables to use system protoc
ENV PROTOBUF_PROTOC=/usr/bin/protoc
ENV GRPC_DOTNET_ENABLE_SYSTEM_PROTOC=true

# Install required workloads for MAUI (only Android as iOS and MacCatalyst require macOS)
#RUN dotnet workload install maui-android

# Copy root-level files first for package resolution
COPY ["Directory.Packages.props", "/"]
COPY ["Directory.Build.props", "/"]
COPY ["Directory.Build.targets", "/"]
COPY ["global.json", "/"]
COPY ["package.json", "/"]
COPY ["package-lock.json", "/"]
COPY ["nuget.config", "/"]
COPY ["eShop.sln", "/"]

# Copy only the project files first to take advantage of Docker layer caching
# This allows us to restore dependencies without having to copy all source code
COPY ["src/Basket.API/Basket.API.csproj", "/src/Basket.API/"]
COPY ["src/Catalog.API/Catalog.API.csproj", "/src/Catalog.API/"]
COPY ["src/eShop.AppHost/eShop.AppHost.csproj", "/src/eShop.AppHost/"]
COPY ["src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "/src/eShop.ServiceDefaults/"]
COPY ["src/EventBus/EventBus.csproj", "/src/EventBus/"]
COPY ["src/EventBusRabbitMQ/EventBusRabbitMQ.csproj", "/src/EventBusRabbitMQ/"]
COPY ["src/Identity.API/Identity.API.csproj", "/src/Identity.API/"]
COPY ["src/IntegrationEventLogEF/IntegrationEventLogEF.csproj", "/src/IntegrationEventLogEF/"]
COPY ["src/Mobile.Bff.Shopping/Mobile.Bff.Shopping.csproj", "/src/Mobile.Bff.Shopping/"]
COPY ["src/Ordering.API/Ordering.API.csproj", "/src/Ordering.API/"]
COPY ["src/Ordering.Domain/Ordering.Domain.csproj", "/src/Ordering.Domain/"]
COPY ["src/Ordering.Infrastructure/Ordering.Infrastructure.csproj", "/src/Ordering.Infrastructure/"]
COPY ["src/OrderProcessor/OrderProcessor.csproj", "/src/OrderProcessor/"]
COPY ["src/PaymentProcessor/PaymentProcessor.csproj", "/src/PaymentProcessor/"]
COPY ["src/WebApp/WebApp.csproj", "/src/WebApp/"]
COPY ["src/WebAppComponents/WebAppComponents.csproj", "/src/WebAppComponents/"]
COPY ["src/WebhookClient/WebhookClient.csproj", "/src/WebhookClient/"]
COPY ["src/Webhooks.API/Webhooks.API.csproj", "/src/Webhooks.API/"]
#COPY ["src/ClientApp/ClientApp.csproj", "/src/ClientApp/"]
#COPY ["src/HybridApp/HybridApp.csproj", "/src/HybridApp/"]

# Restore NuGet packages for all projects
# This ensures all project dependencies are available
RUN dotnet restore "/src/Basket.API/Basket.API.csproj"
RUN dotnet restore "/src/Catalog.API/Catalog.API.csproj"
RUN dotnet restore "/src/eShop.AppHost/eShop.AppHost.csproj"
RUN dotnet restore "/src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj"
RUN dotnet restore "/src/EventBus/EventBus.csproj"
RUN dotnet restore "/src/EventBusRabbitMQ/EventBusRabbitMQ.csproj"
RUN dotnet restore "/src/Identity.API/Identity.API.csproj"
RUN dotnet restore "/src/IntegrationEventLogEF/IntegrationEventLogEF.csproj"
RUN dotnet restore "/src/Mobile.Bff.Shopping/Mobile.Bff.Shopping.csproj"
RUN dotnet restore "/src/Ordering.API/Ordering.API.csproj"
RUN dotnet restore "/src/Ordering.Domain/Ordering.Domain.csproj"
RUN dotnet restore "/src/Ordering.Infrastructure/Ordering.Infrastructure.csproj"
RUN dotnet restore "/src/OrderProcessor/OrderProcessor.csproj"
RUN dotnet restore "/src/PaymentProcessor/PaymentProcessor.csproj"
RUN dotnet restore "/src/WebApp/WebApp.csproj"
RUN dotnet restore "/src/WebAppComponents/WebAppComponents.csproj"
RUN dotnet restore "/src/WebhookClient/WebhookClient.csproj"
RUN dotnet restore "/src/Webhooks.API/Webhooks.API.csproj"
#RUN dotnet restore "/src/ClientApp/ClientApp.csproj"
#RUN dotnet restore "/src/HybridApp/HybridApp.csproj"

# Copy the entire source code after restoring dependencies
# This is more efficient because:
# 1. If only source code changes, we can reuse the cached restore layer
# 2. If .csproj files change, we'll rebuild from that point
COPY . /

# Set the working directory to the root
WORKDIR "/"

# Build the project in Release configuration
# Output the build to /app/build
RUN dotnet build "src/eShop.AppHost/eShop.AppHost.csproj" -c Release -o /app/build

# Create a new stage for publishing
# This stage inherits from the build stage
FROM build AS publish

# Create the output directory
RUN mkdir -p /app/publish

# Publish the application in Release configuration
# Output the published files to /app/publish
RUN dotnet publish "src/eShop.AppHost/eShop.AppHost.csproj" -c Release -o /app/publish && \
    ls -la /app/publish

# Create the final runtime image
# Use the smaller ASP.NET runtime image (no SDK needed)
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final

# Set the working directory for the final image
WORKDIR /app

# Expose ports for HTTP and HTTPS
EXPOSE 80
EXPOSE 443

# Copy only the published files from the publish stage
# This keeps the final image small by not including build tools
COPY --from=publish /app/publish .

# Set the entrypoint to run the application
ENTRYPOINT ["dotnet", "eShop.AppHost.dll"] 
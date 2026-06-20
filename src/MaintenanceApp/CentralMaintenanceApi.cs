using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace Company.MaintenanceApp;

public class CentralMaintenanceApi
{
    private readonly IMaintenanceService _maintenanceService;
    private readonly ILogger<CentralMaintenanceApi> _logger;

    public CentralMaintenanceApi(
        IMaintenanceService maintenanceService,
        ILogger<CentralMaintenanceApi> logger)
    {
        _maintenanceService = maintenanceService;
        _logger = logger;
    }

    [Function("ExecuteMaintenancePipeline")]
    public async Task<IActionResult> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "jobs/execute")] HttpRequest req)
    {
        _logger.LogInformation("Scheduled maintenance signal received.");

        var payload = await JsonSerializer.DeserializeAsync<SchedulerPayload>(
            req.Body,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

        if (payload is null || string.IsNullOrWhiteSpace(payload.JobName))
        {
            return new BadRequestObjectResult(new { error = "JobName is required." });
        }

        _logger.LogInformation(
            "Job {Job} targeting {Target}",
            payload.JobName,
            payload.TargetEnv);

        try
        {
            await _maintenanceService.RunCoreTasksAsync(payload);
            return new OkObjectResult(new { status = "Success", executedJob = payload.JobName });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Maintenance routine failed for {Job}.", payload.JobName);
            return new StatusCodeResult(StatusCodes.Status500InternalServerError);
        }
    }
}

public record SchedulerPayload
{
    public string JobName { get; init; } = string.Empty;
    public string TargetEnv { get; init; } = string.Empty;
    public bool ForceRun { get; init; }
}

public interface IMaintenanceService
{
    Task RunCoreTasksAsync(SchedulerPayload payload);
}

public class MaintenanceService : IMaintenanceService
{
    private readonly ILogger<MaintenanceService> _logger;

    public MaintenanceService(ILogger<MaintenanceService> logger)
    {
        _logger = logger;
    }

    public Task RunCoreTasksAsync(SchedulerPayload payload)
    {
        _logger.LogInformation(
            "Running core tasks for {Job} (force={Force}).",
            payload.JobName,
            payload.ForceRun);

        return Task.CompletedTask;
    }
}


## Management Functions

The management functions in Pode allow you to control and query the status of asynchronous tasks. These functions provide an interface to search, fetch, stop, and check the existence of asynchronous operations within your Pode application. These functions are primarily intended for internal use and are not subject to any permissions or restrictions.

###  Get-PodeAsyncRouteOperation

The ` Get-PodeAsyncRouteOperation` function acts as a public interface for searching asynchronous Pode route operations based on specified query conditions. It allows you to query the status and details of multiple asynchronous tasks based on various parameters.

` Get-PodeAsyncRouteOperation` is similar in intent to `Add-PodeAsyncQueryRoute`. The main difference is that this function is used inside the Pode code to manage Async tasks and is not subject to any permissions or restrictions.

#### Example Usage

```powershell
$queryConditions = @{
    State = @{
        value = "Running"
        op = "EQ"
    }
    Name = @{
        value = "TaskName"
        op = "LIKE"
    }
}

$results =  Get-PodeAsyncRouteOperation -Filter $queryConditions
```

#### Explanation

- **Filter**: A hashtable specifying the query conditions. The keys are the properties of the asynchronous tasks, and the values are hashtables specifying the `value` and `op` (operator) for the query.

---

### Get-PodeAsyncRouteOperation

The `Get-PodeAsyncRouteOperation` function fetches details of an asynchronous Pode route operation by its ID. It allows you to retrieve the status, results, and other information about a specific asynchronous task.

`Get-PodeAsyncRouteOperation` is similar in intent to `Add-PodeAsyncGetRoute`. The main difference is that this function is used inside the Pode code to manage Async tasks and is not subject to any permissions or restrictions.

#### Example Usage

```powershell
$operationDetails = Get-PodeAsyncRouteOperation -Id 'b143660f-ebeb-49d9-9f92-cd21f3ff559c'
```

#### Explanation

- **Id**: The unique identifier of the asynchronous task whose details are to be fetched.

---

### Stop-PodeAsyncRouteOperation

The `Stop-PodeAsyncRouteOperation` function aborts a specific asynchronous Pode route operation by its ID. It sets the task's state to 'Aborted' and disposes of the associated runspace. Returns a hashtable representing the detailed information of the aborted asynchronous route operation.

`Stop-PodeAsyncRouteOperation` is similar in intent to `Add-PodeAsyncStopRoute`. The main difference is that this function is used inside the Pode code to manage Async tasks and is not subject to any permissions or restrictions.

#### Example Usage

```powershell
$abortedOperationDetails = Stop-PodeAsyncRouteOperation -Id 'b143660f-ebeb-49d9-9f92-cd21f3ff559c'
```

#### Explanation

- **Id**: The unique identifier of the asynchronous task to be aborted.

---

### Test-PodeAsyncRouteOperation

The `Test-PodeAsyncRouteOperation` function checks if a specific asynchronous Pode route operation exists by its ID, returning a boolean value.

#### Example Usage

```powershell
$exists = Test-PodeAsyncRouteOperation -Id 'b143660f-ebeb-49d9-9f92-cd21f3ff559c'
```

#### Explanation

- **Id**: The unique identifier of the asynchronous task to be checked.

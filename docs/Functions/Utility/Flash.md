# Flash

## Description

The `flash` function allows you to add messages onto a user's current session. **This does mean that [session middleware](../../../Tutorials/Middleware/Sessions) is required**.

Using flash messages allows you to add informational/error messages to the session, which can be later retrieved on a different web request for the same user session. The act of retrieving a flash message from the session will remove the message. Adding multiple messages under the same key will aggregate them as an array of messages.

Flash messages are useful when validating request data: adding error messages to the session, and then passing them back through to a view on a redirect/reload (ie, sign-up/login pages).

!!! tip
    [`Views`](../../Response/View) have a `-FlashMessages` switch which allows you to automatically load all flash messages into the `$data` of a dynamic view.
    [`Authentication`](../../../Authentication/Overview) checks have a `FailureFlash` option to automatically load error messages in the session.

## Examples

### Example 1

The following example will add a flash message to the session

```powershell
flash add 'address-error' 'Invalid home number supplied for address'
```

### Example 2

The following example will retrieve a flash message - when retrieved, the key will be removed from the current user session

```powershell
flash get 'address-error'
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Action | string | true | The action to perform on the flash message (Values: Add, Clear, Get, Keys, Remove) | empty |
| Key | string | false | The key identifier of the message for later retrieval | empty |
| Message | string | false | The message to add to the key, messages for the same key are appended as an array | empty |
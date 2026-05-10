---
description: >
  Example showing how to pass input data to a PowerShellScript resource and access properties,
  array elements, and nested values inside the script.
ms.date:     05/10/2026
ms.topic:    reference
title:       PowerShell script with input and output
---

# PowerShell script with input and output

This example shows how to pass input data to the `Microsoft.DSC.Transitional/PowerShellScript`
resource and how to bind that data to your script via a `param` block.

## Passing a string as input

When the `input` property is a simple string, it is bound to the first parameter of the script's
`param` block.

```powershell
$instance = @'
getScript: |
  param($inputObj)
  "You passed: $inputObj"
input: Hello, World!
'@

dsc resource get --resource Microsoft.DSC.Transitional/PowerShellScript --input $instance
```

```yaml
actualState:
  output:
    - 'You passed: Hello, World!'
```

## Passing an object as input

When `input` is a YAML mapping, the resource deserialises it into a `PSObject`. Script code can
access individual properties using dot notation.

```powershell
$instance = @'
getScript: |
  param($inputObj)
  "Name:  $($inputObj.name)"
  "Value: $($inputObj.value)"
input:
  name:  MyApp
  value: 42
'@

dsc resource get --resource Microsoft.DSC.Transitional/PowerShellScript --input $instance
```

```yaml
actualState:
  output:
    - 'Name:  MyApp'
    - 'Value: 42'
```

## Passing an array as input

When `input` is a YAML sequence, the resource deserialises it into a PowerShell array. Script code
can index into it or iterate over it.

```powershell
$instance = @'
getScript: |
  param($inputObj)
  "First:  $($inputObj[0])"
  "Second: $($inputObj[1])"
  "Count:  $($inputObj.Count)"
input:
  - alpha
  - beta
'@

dsc resource get --resource Microsoft.DSC.Transitional/PowerShellScript --input $instance
```

```yaml
actualState:
  output:
    - 'First:  alpha'
    - 'Second: beta'
    - 'Count:  2'
```

## Using input in a configuration document

You can pass input to a `PowerShellScript` instance inside a DSC configuration document, including
values from configuration parameters. The following configuration uses the [dsc config get][01]
command to pass a port number into the script:

```yaml
# check-port.dsc.yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
parameters:
  port:
    type: int
    defaultValue: 8080
resources:
  - name: checkPort
    type: Microsoft.DSC.Transitional/PowerShellScript
    properties:
      getScript: |
        param($inputObj)
        "Checking port $($inputObj.port)..."
        Test-NetConnection -ComputerName localhost -Port $inputObj.port |
          Select-Object -ExpandProperty TcpTestSucceeded
      input:
        port: "[parameters('port')]"
```

```powershell
dsc config get --file check-port.dsc.yaml
```

```yaml
executionInformation:
  duration: <time omitted>
  endDatetime: <time omitted>
  executionType: actual
  operation: get
  securityContext: restricted
  startDatetime: <time omitted>
  version: <redacted>
metadata:
  Microsoft.DSC:
    duration: <time omitted>
    endDatetime: <time omitted>
    executionType: actual
    operation: get
    securityContext: restricted
    startDatetime: <time omitted>
    version: <redacted>
results:
- executionInformation:
    duration: <time omitted>
  metadata:
    Microsoft.DSC:
      duration: <time omitted>
  name: checkPort
  type: Microsoft.DSC.Transitional/PowerShellScript
  result:
    actualState:
      output:
      - Checking port 8080...
      - false
messages: []
hadErrors: false
```

## Error: input provided but script has no param block

If you provide a value for `input` but the script does not have a `param(...)` block, the resource
exits with code `2` and emits:

```plaintext
ERROR: Input was provided but script does not have a parameter to accept input.
```

```powershell
$instance = @'
getScript: |
  "No param block here"
input: oops
'@

dsc resource get --resource Microsoft.DSC.Transitional/PowerShellScript --input $instance
# Exit code: 2
```

## Error: param block present but no input provided

Conversely, if the script defines a `param` block but no `input` is supplied, the resource exits
with code `2` and emits:

```plaintext
ERROR: Script has a parameter 'inputObj' but no input was provided.
```

```powershell
$instance = @'
getScript: |
  param($inputObj)
  "This will not run"
'@

dsc resource get --resource Microsoft.DSC.Transitional/PowerShellScript --input $instance
# Exit code: 2
```

<!-- Link definitions -->
[01]: ../../../../../../cli/config/get.md

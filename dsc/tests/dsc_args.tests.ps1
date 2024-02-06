# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'config argument tests' {
    BeforeAll {
        $manifest = @'
        {
            "$schema": "https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/2023/08/bundled/resource/manifest.json",
            "type": "Test/Hello",
            "version": "0.1.0",
            "get": {
                "executable": "pwsh",
                "args": [
                    "-NoLogo",
                    "-NonInteractive",
                    "-NoProfile",
                    "-Command",
                    "'{ \"hello\": \"world\" }'"
                ]
            },
            "schema": {
                "embedded": {
                    "$schema": "http://json-schema.org/draft-07/schema#",
                    "$id": "https://test",
                    "title": "test",
                    "description": "test",
                    "type": "object",
                    "required": [],
                    "additionalProperties": false,
                    "properties": {
                        "hello": {
                            "type": "string",
                            "description": "test"
                        }
                    }
                }
            }
        }
'@

        Set-Content -Path "$TestDrive/Hello.dsc.resource.json" -Value $manifest
        $oldPath = $env:DSC_RESOURCE_PATH
        $sep = [System.IO.Path]::PathSeparator
        $env:DSC_RESOURCE_PATH = $env:PATH + $sep + $TestDrive
    }

    AfterAll {
        $env:DSC_RESOURCE_PATH = $oldPath
    }

    It 'input is <type>' -Skip:(!$IsWindows) -TestCases @(
        @{ type = 'yaml'; text = @'
            keyPath: HKLM\Software\Microsoft\Windows NT\CurrentVersion
            valueName: ProductName
'@ }
        @{ type = 'json'; text = @'
            {
                "keyPath": "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion",
                "valueName": "ProductName"
            }
'@ }
    ) {
        param($text)
        $output = $text | dsc resource get -r Microsoft.Windows/Registry
        $output = $output | ConvertFrom-Json
        $output.actualState.'$id' | Should -BeExactly 'https://developer.microsoft.com/json-schemas/windows/registry/20230303/Microsoft.Windows.Registry.schema.json'
        $output.actualState.keyPath | Should -BeExactly 'HKLM\Software\Microsoft\Windows NT\CurrentVersion'
        $output.actualState.valueName | Should -BeExactly 'ProductName'
        $output.actualState.valueData.String | Should -Match 'Windows .*'
    }

    It '--format <format> is used even when redirected' -TestCases @(
        @{ format = 'yaml'; expected = @'
actualState:
  hello: world
'@ }
        @{ format = 'json'; expected = '{"actualState":{"hello":"world"}}' }
        @{ format = 'pretty-json'; expected = @'
{
  "actualState": {
    "hello": "world"
  }
}
'@ }
    ) {
        param($format, $expected)

        $out = dsc --format $format resource get -r Test/Hello | Out-String
        $LASTEXITCODE | Should -Be 0
        $out.Trim() | Should -BeExactly $expected
    }

    It 'can generate PowerShell completer' {
        $out = dsc completer powershell | Out-String
        Invoke-Expression $out
        $completions = TabExpansion2 -inputScript 'dsc c'
        $completions.CompletionMatches.Count | Should -Be 2
        $completions.CompletionMatches[0].CompletionText | Should -Be 'completer'
        $completions.CompletionMatches[1].CompletionText | Should -Be 'config'
    }

    It 'input can be passed using <parameter>' -TestCases @(
        @{ parameter = '-d' }
        @{ parameter = '--document' }
    ) {
        param($parameter)

        $yaml = @'
$schema: https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/2023/08/config/document.json
resources:
- name: os
  type: Microsoft/OSInfo
  properties:
    family: Windows
'@

        $out = dsc config get $parameter "$yaml" | ConvertFrom-Json
        $LASTEXITCODE | Should -Be 0
        $out.results[0].type | Should -BeExactly 'Microsoft/OSInfo'
    }

    It 'input can be passed using <parameter>' -TestCases @(
        @{ parameter = '-p' }
        @{ parameter = '--path' }
    ) {
        param($parameter)

        $yaml = @'
$schema: https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/2023/08/config/document.json
resources:
- name: os
  type: Microsoft/OSInfo
  properties:
    family: Windows
'@

        Set-Content -Path $TestDrive/foo.yaml -Value $yaml
        $out = dsc config get $parameter "$TestDrive/foo.yaml" | ConvertFrom-Json
        $LASTEXITCODE | Should -Be 0
        $out.results[0].type | Should -BeExactly 'Microsoft/OSInfo'
    }

    It '--document and --path cannot be used together' {
        dsc config get --document 1 --path foo.json 2> $TestDrive/error.txt
        $err = Get-Content $testdrive/error.txt -Raw
        $err.Length | Should -Not -Be 0
        $LASTEXITCODE | Should -Be 2
    }

    It 'stdin and --document cannot be used together' {
        '{ "foo": true }' | dsc config get --document 1 2> $TestDrive/error.txt
        $err = Get-Content $testdrive/error.txt -Raw
        $err.Length | Should -Not -Be 0
        $LASTEXITCODE | Should -Be 1
    }

    It 'stdin and --path cannot be used together' {
        '{ "foo": true }' | dsc config get --path foo.json 2> $TestDrive/error.txt
        $err = Get-Content $testdrive/error.txt -Raw
        $err.Length | Should -Not -Be 0
        $LASTEXITCODE | Should -Be 1
    }

    It 'stdin, --document and --path cannot be used together' {
        '{ "foo": true }' | dsc config get --document 1 --path foo.json 2> $TestDrive/error.txt
        $err = Get-Content $testdrive/error.txt -Raw
        $err.Length | Should -Not -Be 0
        $LASTEXITCODE | Should -Be 2
    }

    It '--trace-level has effect' {
        dsc -l debug resource get -r Microsoft/OSInfo 2> $TestDrive/tracing.txt
        "$TestDrive/tracing.txt" | Should -FileContentMatchExactly 'DEBUG'
        $LASTEXITCODE | Should -Be 0
    }

    It 'stdin cannot be empty if neither document or path is provided' {
        '' | dsc config set 2> $TestDrive/error.txt
        $err = Get-Content $testdrive/error.txt -Raw
        $err.Length | Should -Not -Be 0
        $LASTEXITCODE | Should -Be 4
    }

    It 'document cannot be empty if neither stdin or path is provided' {
        dsc config set --document '' 2> $TestDrive/error.txt
        $err = Get-Content $testdrive/error.txt -Raw
        $err.Length | Should -Not -Be 0
        $LASTEXITCODE | Should -Be 4
    }

    It 'path contents cannot be empty if neither stdin or document is provided' {
        Set-Content -Path $TestDrive/empty.yaml -Value ''
        dsc config set --path $TestDrive/empty.yaml 2> $TestDrive/error.txt
        $err = Get-Content $testdrive/error.txt -Raw
        $err.Length | Should -Not -Be 0
        $LASTEXITCODE | Should -Be 4
    }
}

# 📘 Koreflow Documentation

**Version:** 1.0  
**Created by:** Yuri Bernstein  
**Last Updated:** April 2025

---
 
## Table of Contents
- [Section 0: Running Koreflow](#section-0-running-koreflow)
  - [1. Prerequisites](#1-prerequisites)
  - [2. Configuration file](#2-configuration-file)
  - [3. Running the engine](#3-running-the-engine)

- [Section 1: Workflow Authors](#section-1-workflow-authors)
  - [1. Introduction](#1-introduction)
  - [2. Writing Your First Workflow](#2-writing-your-first-workflow)
  - [3. Matching Engine](#3-matching-engine)
  - [4. Context & Payload](#4-context--payload)
  - [5. Steps](#5-steps)
  - [6. Variables and Outputs](#6-variables-and-outputs)
  - [7. Webform Input](#7-webform-input)
  - [8. Notifications](#8-notifications)
  - [9. Debugging & Recovery](#9-debugging--recovery)

- [Section 2: Module Developers](#section-2-module-developers)
  - [1. Overview](#1-overview)
  - [2. Module Layout](#2-module-layout)
  - [3. Writing Module Code](#3-writing-module-code)
  - [4. Manifests (`module.yaml`)](#4-manifests-moduleyaml)
  - [5. Preflight Validation](#5-preflight-validation)
  - [6. Configuration and Secrets](#6-configuration-and-secrets)
  - [7. Testing Your Module](#7-testing-your-module)
  - [8. Best Practices](#8-best-practices)

- [Section 3: License](#section-3-license)  

---

### 🔧 What is Koreflow?

Welcome to **Koreflow** — a GitOps-native, flexible, and modular workflow automation engine designed for engineers who want full control over operations, approvals, and automation without compromising simplicity or auditability.
Koreflow allows you to define everything declaratively using human-readable YAML, with clear structure and safe execution by design.


## Section 0: Running Koreflow

### 1. Prerequisites
  - Python 3.13
  - Create virtual environment and install the requirements
    ```bash
    pip install -r requirements.txt
    ```

### 2. Configuration file
  Main configuration file is located in configuration/confi.yaml and has it's own README. Please refer to it before starting the engine

### 3. Running the engine
  Engine can be run as a binary file using 
  ```bash
  ./run.sh linux 
  ```
  or 
  ```bash
  ./run.sh macos
  ```
  The binaries can be recompiled using the build scripts located in dev_utils directory

  The engine can also be started with
  ```bash
  python koreflow.py
  ```
  You can wrap either one into a docker of your choice. I will add a Dockerfile in the future
  
## Section 1: Workflow Authors

### 1. Introduction

Hi, I’m [**Yuri Bernstein**](https://www.linkedin.com/in/yuribernstein/),

Koreflow is a tool born out of neccessity of glueing multiple tools together and a consistent need to automate outdated processes.

Koreflow is directly inspired by a core concept I describe in my book:
[**"Letters from the Trenches: The Tech Manager’s Survival Guide."**](https://www.amazon.com/dp/B0F4VK47WW)
### The Operational Blocks Framework (OBF)

> The key to automation isn't just writing scripts.  
> It’s breaking down **processes into reusable, universal blocks**.

Every repeatable operational flow, no matter how complex, can be expressed as a series of five **Operational Blocks**:

| Block | Description                                     |
|-------|-------------------------------------------------|
| 🟦 **Ask**  | Request structured input (e.g., form, Slack)   |
| 🟩 **Act**  | Perform an action (deploy, restart, etc.)      |
| 🟨 **Gate** | Wait for approval or external decision         |
| 🟧 **Wait** | Pause until a condition or event is met        |
| 🟥 **State**| Report or publish result/status                |


These building blocks are at the core of **Koreflow**.  
You don’t need to learn a new language or platform.  
You simply declare what to ask, what to do, what to wait for, and what to report.

The system interprets these blocks, enforces structure, manages execution, and integrates with Slack, APIs, approvals, forms, and more — all with **Git-native, state-aware workflows.**


Koreflow is a Git-backed engine that:

- Listens for incoming events (like GitHub webhooks or API calls),
- Matches them against user-defined conditions,
- Executes multi-step workflows defined in **YAML**,  
- Interacts with **external systems** via pluggable modules,
- Collects **user input** via forms or approvals,
- Tracks and persists state across restarts.

It's purpose-built for **DevOps**, **SRE**, **Support**, and **internal tooling** use cases, but due to it's flexibility it can be used for anything and anywhere.

---

### How It Works – Quick Overview

Every workflow can be triggered using different methods:api | git | scheduled | ad-hoc | aiagent (check docs/agents.md for more details).

The process is:

```
[ Event Trigger ]
        ↓
[ Matching Engine ] ← based on your match block
        ↓
[ Workflow Execution Engine ]
        ↓
[ Step-by-step Execution in any order ]
        • action steps (call module methods)
        • approval steps (wait for user)
        • webform steps (collect data)
```

Each workflow is defined in a `.yaml` file, placed in a Git-managed directory. Workflows contain steps, conditions, variables, and references to reusable **modules** (which are just Python classes with method definitions).

---

### Why Koreflow?
There are many great tools out there, but here is what Koreflow has to offer

| Feature                      | Benefit                                                                         |
|------------------------------|---------------------------------------------------------------------------------|
| GitOps-native                | All workflows, modules, and variables live in Git                               |
| Modular                      | Easily extend with Python-based plugins - write your own modules!               |
| Declarative                  | Use clear YAML structures to define your workflows                              |
| Safe Execution               | Step-level tracking with safeguards in place                                    |
| Approval & Input Support     | Approvals, Slack, and fully dynamic webforms                                    |
| Durable & Recoverable        | Workflows resume from last successful step                                      |

---

### Key Concepts

| Term          | Description |
|---------------|-------------|
| **Workflow**  | A `.yaml` file that defines conditions and steps |
| **Step**      | A single unit of work in a workflow (e.g., action, approval, form) |
| **Module**    | A Python class with methods you call from your YAML |
| **Context**   | A dynamic dictionary storing variables and results |
| **Match**     | Conditions that decide whether a workflow should run |
| **Approval**  | Human confirmation step (Link or Webform) |
| **Form**      | A configurable UI to collect structured user input |

---

### Who Should Use This?

- DevOps/SREs automating internal ops processes  
- Engineers building self-service flows (onboarding, provisioning, integration, deployment)  
- Developers looking for audit-friendly workflow engines  
- Platform teams integrating systems with human checkpoints


- Key components:
  - GitOps workflows
  - YAML DSL
  - Triggers (event, cron)
  - Step types: `action`, `approval`, `webform`

---


### 2. Writing Your First Workflow

Koreflow workflows are defined in simple YAML files and organized inside `wprkflows/<subfolder>` directory. Each `subfolder` may contain one or many workflows and is auto-discovered on startup and at runtime.

---

#### Directory Structure

Each workflow lives inside the `workflows/` folder of a registered repository:

```
  workflows/operations
                ├── deploy_to_prod.yaml
                └── rotate_cert.yaml
```

Each file defines a full workflow using the Koreflow DSL.

On startup, the engine scans the folder structure and automatically registers the following route:

```
POST /api/<subfolder>/<workflow_name>
```

For example:

```
POST /api/operations/deploy_to_prod
```

---

#### Minimal Example

Here’s a basic workflow that reacts to a payload with `mode: test` and sends a Slack message:

```yaml
workflow:
  name: hello_world

  match:
    conditions:
      - path: payload.mode # parses the incoming payload searching for the key `mode`
        operator: equals
        value: "test"      # checks if they value of the key `mode` matches to `test`
        id: test_mode      # registes matching condition as `test_mode`
    condition_logic: test_mode  # if `test_mode` condition is true (e.g. payload.mode is `test`) then the workflow will be executed

  payload_parser:
    - path: payload.user   #  parses the incoming payload searching for the key `user`
      var: user            # registers the value from the payload as variable `user` in the workflow context, allowing to re-use it
      absent_action: ignore # if the value is not present - workflow will continue. if not set - workflow will fail

  context_variables:   
    - name: channel
      default: "#general"

  steps:
    - id: say_hello
      type: action
      action: slack_module.Slack.send_info_message
      input:
        channel: "{{ context.channel }}"
        title: "Hello!"
        message: "Triggered by {{ context.user or 'unknown' }}"
```

---

#### Running the Workflow

Use `curl` to trigger execution:

```bash
curl -X POST http://localhost:8080/api/samples/sample \
  -H "Content-Type: application/json" \
  -d '{"mode": "test", "user": "Yuri"}'
```

If the match conditions pass, the engine runs the workflow step by step and delivers a message to Slack.
(you will have to configure slack integration for it to work - more on that later)
---

#### What Happens Behind the Scenes

- Koreflow discovers your `.yaml` files and binds them to API endpoints.
- It waits for a trigger (e.g. webhook, CLI, or `curl`) containing a payload.
- It evaluates the `match:` block to decide whether to run.
- If the match passes, it extracts values into `context` using `payload_parser`.
- Then, it runs each `step`.

---

#### Pro Tips

- You can have multiple workflows per repo.
- Route format: `/api/<subfolder>/<workflow_name>`
- You can nest logic inside steps with conditions and dynamic variable registration.
- All values become part of the live workflow context — accessible with `{{ context.xxx }}`


---


### 3. Matching Engine

Before a workflow runs, Koreflow first checks whether it should run — using the match: block. This is how you bind workflows to specific events, payloads, or conditions — without writing code.

Think of it as a router + filter — only matching events trigger execution.

---

#### Conditions Structure

```yaml
match:
  conditions:
    - path: payload.mode
      operator: equals
      value: "test"
      id: is_test
    - path: payload.repo.name
      operator: is_in
      value: ["infra", "tools"]
      id: valid_repo

  condition_logic: is_test and valid_repo
```

---

#### Fields

| Field            | Description                                                                 |
|------------------|-----------------------------------------------------------------------------|
| `conditions`     | A list of evaluations applied to the incoming JSON payload                  |
| `path`           | Dot-notation path into the payload (supports `[*]` wildcard for arrays)     |
| `operator`       | The logic applied to the extracted value                                    |
| `value`          | The expected value (required for most operators)                            |
| `id`             | A short name used in `condition_logic` to refer to this condition           |
| `condition_logic`| Boolean expression combining condition IDs with `and`, `or`, `not`, etc.    |

---

#### Supported Operators

| Operator         | Logic                                                               |
|------------------|---------------------------------------------------------------------|
| `equals`         | `actual == value`                                                   |
| `not_equals`     | `actual != value`                                                   |
| `present`        | Value is not `None`                                                 |
| `absent`         | Value is `None` or missing                                          |
| `is_in`          | `actual in value` (value must be a list)                            |
| `not_in`         | `actual not in value`                                               |
| `contains`       | `value in actual` (only for `actual` that is a string)              |
| `not_contains`   | `value not in actual` (only for `actual` that is a string)          |
| `starts_with`    | `actual.startswith(value)` (only for strings)                       |
| `length`         | `len(actual) == value` (for lists or strings)                       |

> Note: Some operators like `present`, `absent`, and `length` don’t need a `value` field.

---

#### Path Resolution

Paths follow dot-notation:
```yaml
payload.repo.name
```

You can also use wildcard array selectors like:
```yaml
payload.labels[*]
```

Internally, these paths are resolved by the `extract_json_path()` function and support basic list flattening, but **not** complex JSONPath features.

---

#### Logic Expressions

The `condition_logic` field supports:
- `and`, `or`, `not`
- Parentheses `()` for grouping
- Securely evaluated using Python’s AST parser

Example:
```yaml
condition_logic: is_test and (valid_repo or not has_issue)
```

---

#### Security & Evaluation Notes

- All expressions are parsed with `ast` for safety.
- Only a limited subset of logical operations and symbols are allowed.
- Evaluation failures are logged and return `False`.

---

#### Debugging Match Logic

Use debug mode to trace actual values:

```bash
[ MATCH ] is_test: path=payload.mode actual="test" → True
[ MATCH ] valid_repo: path=payload.repo.name actual="infra" → True
[ MATCH LOGIC ] is_test and valid_repo → True
```

If no match occurs, the workflow will **not run**:

```json
{
  "status": "ignored",
  "reason": "match conditions not met"
}
```

---

#### Gotchas

- `value` must match types exactly (string vs int matters).
- For `is_in` / `not_in`, the **`value` must be a list**.
- Use `present` and `absent` for defensive conditions.

---


### 4. Context & Payload

Once a workflow is matched, it needs **data** to work with. That’s where **`context`** comes in.

The `context` is a key-value dictionary that stores everything your workflow needs: parsed fields from the payload, predefined variables, outputs from previous steps, form inputs, approval results, and more.

This section explains how to build and use context data using `payload_parser` and `context_variables`.

---

#### `payload_parser`

Extract fields from the incoming payload and assign them to named context variables.

```yaml
payload_parser:
  - path: payload.repo.name
    var: repo_name
  - path: payload.author
    var: author
    absent_action: ignore
```

| Field          | Description                                              |
|----------------|----------------------------------------------------------|
| `path`         | Dot-notation path to extract value from the payload      |
| `var`          | Name to store the result in context                      |
| `absent_action`| Optional: `fail` (default) or `ignore`                   |

If the field is missing and `absent_action` is not set to `ignore`, the workflow **will fail** before execution.

---

#### `context_variables`

Define default or constant variables to be used inside your workflow.

```yaml
context_variables:
  - name: channel
    type: string
    default: "#ops-alerts"
    description: "Default Slack channel for notifications"
```

| Field         | Description                                               |
|---------------|-----------------------------------------------------------|
| `name`        | Variable name (becomes `context.name`)                    |
| `type`        | Optional type hint (`string`, `int`, `object`, `array`)   |
| `default`     | Default value (used if not overridden by payload)         |
| `description` | Optional field for documentation clarity                  |

---

#### How Context Is Built

The context is populated in this order:

1. Values from `context_variables` (defaults),
2. Values extracted via `payload_parser`,
3. Variables registered during step execution (`register_output`, `register_vars`),
4. External approval or form inputs (like `form_result`),
5. Any dynamically computed or templated variables.

---

#### Example

Incoming JSON:
```json
{
  "payload": {
    "mode": "test",
    "user": "alice"
  }
}
```

YAML:
```yaml
payload_parser:
  - path: payload.mode
    var: mode
  - path: payload.user
    var: user

context_variables:
  - name: channel
    default: "#general"
```

Resulting context:
```json
{
  "mode": "test",
  "user": "alice",
  "channel": "#general"
}
```

---

#### Using Context in Your Workflow

Anywhere in the workflow YAML, you can reference values like:

```yaml
input:
  user: "{{ context.user }}"
  channel: "{{ context.channel }}"
```

Or even apply logic:
```yaml
condition: "{{ context.mode }} == 'test'"
```

These values are rendered using Jinja-like templating and evaluated at runtime with full context awareness.

---

#### Notes

- All context values are **strings** unless explicitly set or parsed differently.
- You can safely nest values (e.g., `context.form_result.form_data.start`)
- Use `absent_action: ignore` for optional fields to avoid breaking execution.


---

### 5. Steps

Each workflow is a sequence of **steps**.  
A step defines a single unit of work — like calling a function, waiting for approval, or collecting data from a form.

Steps are declared in a list under `workflow.steps`, and are executed in the order they appear.

---

### Basic Step Structure

```yaml
- id: fetch_info
  type: action
  action: example_module.Example.fetch
  input:
    param1: "{{ context.user }}"
  register_output: fetch_result
```

| Field             | Description                                                                 |
|------------------|-----------------------------------------------------------------------------|
| `id`             | Required. Unique step ID within the workflow.                               |
| `type`           | `action`, `approval`, or `webform`.                                         |
| `action`         | For `action` steps: module.class.method to call.                            |
| `input`          | Dict passed as kwargs to the method. Supports templating.                   |
| `conditions`     | Optional condition(s) to run this step (see below).                         |
| `register_output`| Store method result in context under a named key.                           |
| `register_vars`  | Compute additional variables after the step.                                |

---

### Step Types

#### 1. `type: action`

Calls a method from a loaded Python module.

```yaml
- id: notify
  type: action
  action: slack_module.Slack.send_info_message
  input:
    channel: "{{ context.channel }}"
    title: "Status Update"
    message: "User {{ context.user }} just ran this workflow."
```

- The module method receives `**input`.
- Execution results are stored under `context.step_results.notify.status` `context.step_results.notify.message` and `context.step_results.notify.data` where `notify` is your step id.
- You can access the step results in other steps.

---

#### 2. `type: approval`

Generates an approval link and waits for a manual approval (via link hit).

```yaml
- id: approve_step
  type: approval
  message: "Do you want to deploy to production?"
  timeout_minutes: 60
  delivery_step:
    id: send_slack
    type: action
    action: slack_module.Slack.send_incident_message
    input:
      channel: "{{ context.channel }}"
      message: "Approval required: {{ context.approval_link }}"
```

- Generates an approval link like `/approve/<workflow_uid>/<step_id>`
- Blocks until user approves or timeout hits
- Optional `delivery_step` sends notification before blocking

---

#### 3. `type: webform`

Launches a dynamic form (React-based) and waits for user input.

```yaml
- id: gather_info
  type: webform
  module: webform
  config_file: wf_config.js
  css_file: custom.css
  timeout_minutes: 120
  delivery_step:
    id: notify_link
    type: action
    action: slack_module.Slack.send_message
    input:
      channel: "{{ context.channel }}"
      message: "Please complete the form: {{ context.approval_link }}"
```

- Form is configured by the passed `config_file`
- Submitted data is returned into context under `register_output`
- Form results are available in the context just like any other step results

---

### Conditional Step Execution

You can make any step conditional using the `conditions` field.

```yaml
conditions:
  - name: only run if mode is prod
    condition: "{{ context.mode }} == 'prod'"
```

Each condition is templated and evaluated as a Python `bool`.

If any condition is `false`, the step is **skipped**.

---

### `register_vars`

As an alternative to `context.step_results` you can use this to define or derive additional context variables after a step runs.

```yaml
register_vars:
  - name: severity
    conditional:
      - if: "{{ context.fetch_result.status == 'error' }}"
        value: sev1
      - elif: "{{ context.fetch_result.status == 'warning' }}"
        value: sev2
      - default: info
```

You can also assign simple values:

```yaml
  - name: api_status
    value: "{{ context.fetch_result.status }}"
```

---

### Example: All Combined

```yaml
- id: get_data
  type: action
  action: api_module.Api.fetch_data
  input:
    url: "https://api.example.com"
  register_output: api_result
  register_vars:
    - name: status
      value: "{{ context.api_result.status }}"

- id: alert_ops
  type: action
  conditions:
    - name: only on failures
      condition: "{{ context.status }} == 'error'"
  action: slack_module.Slack.send_incident_message
  input:
    channel: "#ops"
    message: "API call failed"
```

---


## 6. Variables and Outputs

Koreflow provides a powerful context system that lets you:

- Store results of steps
- Define new variables
- Compute conditional values
- Access all data using `{{ context.var }}` syntax

All variables live in the **context**, which is shared across the entire workflow execution.

---

### `register_output`

Every `action`, `approval`, or `webform` step can capture its result into the context:

```yaml
- id: fetch_user
  type: action
  action: user_module.User.get_user_info
  input:
    username: "{{ context.user }}"
  register_output: user_info
```

This saves the method’s return value as `context.user_info`.

You can reference it later:

```yaml
input:
  message: "User email: {{ context.user_info.email }}"
```

---

### `register_vars`

Use this to define additional variables derived from previous results.

You can use:

#### Direct Value

```yaml
register_vars:
  - name: email
    value: "{{ context.user_info.email }}"
```

#### ✅ Conditional Values

```yaml
register_vars:
  - name: severity
    conditional:
      - if: "{{ context.user_info.role == 'admin' }}"
        value: "sev1"
      - elif: "{{ context.user_info.role == 'manager' }}"
        value: "sev2"
      - default: "info"
```

#### Optional: `absent_action`

If the value can’t be rendered (e.g., missing field), you can choose to fail or ignore:

```yaml
register_vars:
  - name: user_id
    value: "{{ context.user_info.id }}"
    absent_action: ignore
```

Default is `fail`, which throws an error if the value can't be resolved.

---

### Tips for Variable Usage

- Variables are accessible as `{{ context.var_name }}`
- All parsed values (from payload) and registered outputs are stored here
- Avoid overwriting context keys unless intentional
- Use `register_output` when you need the full method return
- Use `register_vars` when you want to extract or compute smaller pieces

---

### From Webform Steps

If you use a `webform`, the form result is stored as structured data:

```yaml
- id: gather_info
  type: webform
  ...
  register_output: form_result
```

The result will be available as:

```yaml
context.form_result.form_data.<field_id>
```

You can use `register_vars` to extract individual fields:

```yaml
register_vars:
  - name: dc
    value: "{{ context.form_result.form_data.regular_data_center }}"
```

---

### 📦 Example

```yaml
- id: get_status
  type: action
  action: api_module.Api.check_status
  input:
    id: "{{ context.ticket_id }}"
  register_output: api_response
  register_vars:
    - name: is_resolved
      conditional:
        - if: "{{ context.api_response.status == 'closed' }}"
          value: true
        - default: false
```

---


## 7. Webform Input

Webforms in **Koreflow** are a native way to collect structured, multi-step user input as part of a workflow. Whether you’re gathering deployment metadata, provisioning details, or human-verified parameters — webforms help turn vague approvals into **real, validated input**.

This is your **🟦 Ask block** in the Operational Blocks Framework (OBF), and it follows the UX principles of **minimalism with power** and **progressive disclosure**, as described in *Letters from the Trenches*.

---

### 🧱 Step Type: `webform`

```yaml
- id: gather_input
  type: webform
  module: webform
  config_file: wf_env_selection.js
  css_file: custom.css
  timeout_minutes: 60

  delivery_step:
    id: notify_user
    type: action
    action: slack_module.Slack.send_info_message
    input:
      channel: "{{ context.channel }}"
      title: "Input Required"
      message: "Please complete this form: {{ context.approval_link }}"

  register_output: form_result
```

---

### How It Works

- You specify which **form config** to use via `config_file` in the step.
- Koreflow renders the webform using a **React-based dynamic wizard**, and serves it at a unique per-workflow link.
- The form can include inputs, dropdowns, API-triggers, conditional logic, or even error-handling pages.
- Once submitted, the data becomes part of the workflow’s `context`.

---

### What is a `config_file`?

Each webform is defined in a JavaScript module (e.g. `wf_env_selection.js`) that exports a **wizardConfig** object. This describes the form’s structure, steps, logic, and behavior.

You can create different config files for different use cases:
- `wf_deploy.js` for production rollouts
- `wf_escalation.js` for incident escalation
- `wf_env_selection.js` for environment provisioning

These are **true UX-driven** forms — no boilerplate HTML, no frontend development needed.

---

### UX Philosophy: Minimalism with Power

The form follows principles laid out in *Letters from the Trenches*:
- **Minimalism**: Each screen focuses on one step, one question.
- **Progressive Disclosure**: Complex logic is revealed only as needed.
- **Human-readable fields** with icons, clear labels, and simple navigation.
- **Valid JSON output**, injected directly into workflow context.

---

### Example: Environment Setup Request

Let’s walk through a realistic multi-path scenario (renamed to be infrastructure-agnostic):

```js
const wizardConfig = {
  steps: [
    {
      id: "start",
      type: "junction",
      question: "What do you want to configure?",
      iconName: "Settings",
      options: [
        { label: "Environment Setup", nextStep: "env_type" },
        { label: "Service Validation", nextStep: "validation_entry" }
      ]
    },
    {
      id: "env_type",
      type: "dropdown",
      label: "Environment Type",
      iconName: "Environment",
      options: ["Dev", "QA", "Staging", "Prod"],
      nextStep: "select_region"
    },
    {
      id: "select_region",
      type: "dropdown",
      label: "Select Region",
      options: ["us-west", "us-east", "eu-west", "ap-south"],
      iconName: "Globe",
      nextStep: "owner_email"
    },
    {
      id: "owner_email",
      type: "input",
      label: "Team Contact Email",
      iconName: "Mail",
      nextStep: "multi_services"
    },
    {
      id: "multi_services",
      type: "multiinput",
      label: "Add Required Services",
      max_inputs: 5,
      iconName: "Service",
      nextStep: "need_ticket"
    },
    {
      id: "need_ticket",
      type: "junction",
      iconName: "Jira",
      label: "Need to create a ticket?",
      options: [
        { label: "Yes", nextStep: "ticket_description" },
        { label: "No", nextStep: "submit_ticket_id" }
      ]
    },
    {
      id: "submit_ticket_id",
      type: "input",
      iconName: "Jira",
      label: "Existing Ticket ID",
      nextStep: "submit"
    },
    {
      id: "ticket_description",
      type: "textbox",
      iconName: "Jira",
      label: "Ticket Description",
      nextStep: "submit"
    },
    {
      id: "validation_entry",
      type: "input",
      label: "Enter service name",
      iconName: "Service",
      nextStep: "trigger_check"
    },
    {
      id: "trigger_check",
      type: "api-trigger",
      label: "Run Validation",
      iconName: "Rocket",
      apiCall: "/api/validate_service",
      payloadField: "validation_entry",
      successNextStep: "submit",
      failureNextStep: "error_step"
    },
    {
      id: "error_step",
      type: "info",
      label: "Validation Failed",
      text: "Something went wrong. Please fix input or contact support.",
      nextStep: "validation_entry"
    },
    {
      id: "submit",
      label: "Submit Form",
      headers: { "Content-Type": "application/json" },
      type: "submit"
    }
  ]
};

export default wizardConfig;
```

---

### What You Get

Once submitted, this form yields:

```json
{
  "status": "approved",
  "form_data": {
    "env_type": "QA",
    "select_region": "us-west",
    "owner_email": "devops@example.com",
    "multi_services": ["auth", "billing"],
    "ticket_description": "Need this deployed by EOD"
  }
}
```

Which becomes accessible in your workflow via:

```yaml
{{ context.form_result.form_data.multi_services }}
{{ context.form_result.status }}
```


---

## 8. Notifications

Koreflow includes a built-in notification system, with first-class support for **Slack messages**, alerts, and approvals. Notifications are handled via modules (e.g. `slack_module`) and declared using `action` steps in your workflow YAML.

You can use Slack notifications to:
- Alert on form submissions
- Request approvals
- Report status updates
- Send structured information

---

### Example: Sending a Message via Slack

```yaml
- id: notify_ops
  type: action
  action: slack_module.Slack.send_info_message
  input:
    channel: "{{ context.channel }}"
    title: "New Submission Received"
    message: "Workflow {{ context.workflow_uid }} submitted successfully."
  register_output: notify_result
```

---

### Supported Slack Methods

Your Slack module can expose multiple methods — for example:

```yaml
methods:
  - send_info_message
  - send_incident_message
```

These are defined in the module’s `Slack.py` file and registered in `module.yaml`.

#### `send_info_message`

For general info messages with a title and body:

```yaml
input:
  channel: "#ops-alerts"
  title: "Something happened"
  message: "Here's what you need to know..."
```

#### `send_incident_message`

Used for severity-based alerts:

```yaml
input:
  channel: "#incident-response"
  message: "Critical alert for service XYZ"
  severity: "sev2"
  oncall_user: "{{ context.user }}"
```

The `severity` field maps to specific Slack color codes for attachments.

---

### Dynamic `keyed_message`

You can send structured data as a list of labeled fields, like this:

```yaml
input:
  channel: "#ops"
  title: "Deployment Details"
  keyed_message:
    - key: "Environment"
      value: "{{ context.env_type }}"
    - key: "User"
      value: "{{ context.user }}"
    - key: "Form Status"
      value: "{{ context.form_result.status }}"
```

This is rendered as a Slack message attachment with labeled fields:

```
┌───────────────────────┐
│ Deployment Details    │
├────────────┬──────────┤
│ Environment│ prod     │
│ User       │ yuri     │
│ Form Status│ approved │
└────────────┴──────────┘
```

You can combine both:

```yaml
input:
  channel: "#alerts"
  title: "Form Submitted"
  message: "A new request was submitted"
  keyed_message:
    - key: "Region"
      value: "{{ context.form_result.form_data.select_region }}"
    - key: "Email"
      value: "{{ context.form_result.form_data.owner_email }}"
```

---

### Best Practices

- Always template dynamic values via `{{ context.var }}`.
- Use `keyed_message` for structured display.
- For approvals, use Slack in combination with `approval` or `webform` steps.

---


## 9. Debugging & Recovery

Koreflow is designed for **durability and observability**. Every workflow run is tracked, persisted, and can be resumed if interrupted — with full introspection via structured logs and state files.

---

### 🪵 Log Files

Logs are written per component, stored in the `./logs` folder. Key files:

| File | Purpose |
|------|---------|
| `logs/workflow_engine.log` | Core engine execution (step-by-step) |
| `logs/match_engine.log` | Match logic evaluation details |
| `logs/approval_manager.log` | Approvals, webforms, and status tracking |
| `logs/slack_module.log` | Slack integration, webhooks, errors |
| `logs/flask_app.log` | Web server, routing, module serving |

Each log uses structured `[timestamp] [component]` format for easy grepping.

---

### Persistent State

Every running workflow creates a **lifetime file** under:

```
lifetimes/<workflow_uid>.yaml
```

This file captures:
- Workflow definition
- Context variables
- Current step
- Reason for last update
- Timestamps

When a workflow is completed, it’s automatically moved to:

```
lifetimes/completed/
```

These files act as **both execution trace and recovery anchor.**

---

### Auto-Resume

On startup, Koreflow scans all incomplete workflows in the `lifetimes/` directory and resumes them automatically:

```python
def resume_pending_workflows():
    runs = discover_recoverable_runs()
    for run in runs:
        threading.Thread(
            target=resume_workflow_from_lifetime,
            args=(run, approval_manager),
            daemon=True
        ).start()
```

The engine picks up at the last unfinished step, with full context reloaded.

---

### Troubleshooting Tips

| Symptom | Check |
|--------|--------|
| Workflow doesn’t trigger | `match_engine.log` — see match result |
| Form never completes | Make sure `submit` hits the `/submit` endpoint and includes UID/step ID |
| Output missing | Check `register_output` or `register_vars` placement |
| Approval stuck | Ensure approval route exists and wasn’t timed out |
| Form shows error | JS console in browser; check config path or missing assets |

---

## Section 2: Module Developers


### 1. Overview

Koreflow is modular by design. Each **step** in a workflow calls a method from a **module**, which is just a Python class.

You can think of a module as a plug-in — it provides reusable logic that can be invoked declaratively from YAML.

#### Examples of what modules can do:
- Send Slack messages
- Call internal APIs
- Provision infrastructure
- Post JIRA tickets
- Validate input
- Interact with GitHub, Datadog, PagerDuty, etc.

---

### Why Write a Module?

You’ll want to create a module when:
- A piece of logic is reusable across multiple workflows
- It needs secrets/configuration (e.g., API keys)
- It calls external systems
- It encapsulates multi-step behavior (e.g., sending + logging + retry)

Koreflow modules are:
- **Self-contained**
- **Configurable**
- **Type-safe** (by convention, not strict typing)
- And automatically validated during workflow load.

---

### A Valid Module Must:
- Be placed under `modules/<your_module_name>/`
- Contain a `module.yaml` manifest
- Include a Python file with a class and one or more callable methods
- Optionally: provide `config.yaml`, assets, or helper files

---

### Example: Slack Module Layout

```bash
repos/modules/slack_module/
├── slack.py             # Main module logic
├── module.yaml          # Describes class and methods
└── usage_reference.yaml # Usage examples
```

In `module.yaml`:

```yaml
name: slack_module
class: Slack
methods:
  - send_info_message
  - send_incident_message
```

In `slack.py`:

```python
class Slack:
    def __init__(self, context):
        self.context = context
        self.config = get_config()  # Loads from config.yaml

    def send_info_message(self, channel, title, message):
        ...
```

---


### 2. How Modules Integrate with the Workflow DSL (SDSL)

Koreflow’s execution engine dynamically invokes your module’s Python methods based on the YAML workflow definition.

Every `action` step in your workflow calls:

```
<module>.<Class>.<method>
```

Let’s break down how each of these is tied together:

---

### Folder Name → Module Name

The module name in your YAML DSL corresponds to the **folder** name inside `modules/`.

#### Example:

```yaml
action: slack_module.Slack.send_info_message
```

- Koreflow looks for a directory:  
  `modules/slack_module/`

---

### `module.yaml` → Class & Methods

Inside `repos/modules/slack_module/`, you must have a `module.yaml` like:

```yaml
name: slack_module
class: Slack
methods:
  - send_info_message
  - send_incident_message
```

- `class` → the Python class name defined in `Slack.py`
- `methods` → list of callable methods allowed in YAML

> 🔐 This manifest is **validated at startup** to prevent calling unsafe or undefined methods.

---

### Python Code: Class + Methods

You must have a file like `slack.py` that contains the specified class and methods:

```python
class Slack:
    def __init__(self, context):
        self.context = context  # full context injected

    def send_info_message(self, channel, title, message):
        ...
```

Koreflow creates one instance per workflow execution and calls the method dynamically using reflection.

---

### YAML: The `action` Line

In your YAML:

```yaml
- id: notify
  type: action
  action: slack_module.Slack.send_info_message
  input:
    channel: "#ops"
    title: "Incident Update"
    message: "Something failed"
```

This triggers:
```
modules/slack_module/Slack.py → Slack.send_info_message(channel, title, message)
```

Arguments in `input:` must match method parameters. You can also use Jinja templates with `{{ context.variable }}`.

---

### Summary Mapping

| DSL Element           | Tied To                                               |
|-----------------------|--------------------------------------------------------|
| `action:`             | Path to `module.class.method`                         |
| `modules/`            | Must contain a folder matching the module name        |
| `module.yaml`         | Declares `class:` and `methods:`                     |
| Python method args    | Declared via `input:` in the workflow step            |
| `context` injection   | Automatically passed into class constructor           |
| `register_output:`    | Receives return value of method (any Python object)   |

---


### 3. Writing Module Code

Each Koreflow module is a plain Python class that defines one or more callable methods. These methods can be used in workflows as `action` steps.

Modules are instantiated per workflow run and are provided the full `context` dictionary automatically.

#### Minimal Module Template

```python
from slack_sdk import WebClient
from engine.utils.logs import get_logger
from slack_module.config_getter import get_config

logger = get_logger("slack_module")

class Slack:
    def __init__(self, context):
        self.context = context
        self.config = get_config()  # from config.yaml
        self.client = WebClient(token=self.config["slack_token"])

    def send_info_message(self, channel, title, message):
        logger.info(f"Sending info message to {channel}")
        response = self.client.chat_postMessage(
            channel=channel,
            text=title,
            attachments=[
                {
                    "color": "#36a64f",
                    "fields": [
                        {
                            "title": "Message",
                            "value": message or "N/A",
                            "short": True
                        }
                    ]
                }
            ]
        )
        return {
            "status": "sent",
            "ts": response["ts"],
            "channel": channel
        }
```

---

### Class and Method Requirements

| Rule | Description |
|------|-------------|
| `__init__(self, context)` | Required. Receives the workflow context object |
| Method names | Must match those listed in `module.yaml → methods:` |
| Method args  | Declared in `input:` block in the workflow YAML |
| Method return | Must be a dictionary with {'status', 'message', 'data'}|

Remember handling exceptions gracefuly, letting the use define how to handle an error at the workflow level, rather then deciding for him

---

### Parameter Passing

When a workflow runs:

```yaml
- id: notify
  type: action
  action: slack_module.Slack.send_info_message
  input:
    channel: "#ops"
    title: "Incident Update"
    message: "Something failed"
```

The engine does this internally:

```python
instance = Slack(context)
result = instance.send_info_message(
    channel="#ops",
    title="Incident Update",
    message="Something failed"
)
```

If your method signature doesn’t match the `input:` fields — execution will fail.

---

### Tips

- Make sure `input:` values match method parameters exactly.
- Use `self.context.get("key")` to access context dynamically inside the module.
- You can log intermediate values with `logger.debug(...)` or `logger.info(...)`.


---

### 4. Manifests (`module.yaml`)


Every module in Koreflow must include a manifest file named `module.yaml`.

This file tells the engine:

- What class to load
- Which methods are safe to call from YAML
- How to locate the module

It acts as both a contract and a safety mechanism — allowing only explicitly declared methods to be called.

---

### Example

```yaml
name: slack_module
class: Slack
methods:
  - send_info_message
  - send_incident_message
```

---

### Field Reference

| Field     | Required | Description |
|-----------|----------|-------------|
| `name`    | ✅        | Must match the folder name in `modules/` |
| `class`   | ✅        | The Python class in your module file (`slack.py`) |
| `methods` | ✅        | A list of **allowed methods** exposed to YAML DSL |

---

### Module Folder Structure

```bash
modules/slack_module/
├── slack.py
├── module.yaml
├── config.yaml        # optional
└── utils/             # optional
```

---


#### Why It Matters

Koreflow uses the manifest for **safe reflection**. This prevents:

- Accidental method exposure
- Unsafe calls like `os.system()` being reachable
- Typos in workflow files

If a method is not listed in `methods:`, it cannot be called — even if it exists in the class.

---

### Module File Discovery

The file containing your class (e.g., Slack) does not need to be named after the module folder. Koreflow will scan all .py files in the module directory and locate the one that defines the class specified in module.yaml.

For example:

```bash
modules/slack_module/
├── slack.py         # Contains class Slack
├── module.yaml      # Declares class: Slack
...
```

Koreflow loads each .py file and checks if it contains the expected class. If the class is found, it is used to execute declared methods.

### Benefits

Flexible naming for Python files (e.g., slack.py, not slack_module.py)
- Support for modular folder structures
- Better readability and maintainability
This behavior ensures your module structure remains intuitive without sacrificing declarative clarity in the manifest.

--- 

### Best Practices

- Keep `methods:` list minimal and intentional
- One class per module (for now) — use `utils/` subfolder in the module directory for helpers
- Always validate `module.yaml` before committing

---

### Advanced Ideas (Future Extensions)

While not yet implemented, the manifest may support:

- Input validation schemas
- Descriptions for methods (for auto-doc generation)
- Method metadata (e.g., async support, retries)
- Access control (e.g., public vs internal methods)

---

### 5. Preflight Validation

Before any workflow executes, Koreflow performs a **preflight validation** step. This ensures that all referenced modules, classes, and methods are valid and callable — preventing broken workflows from reaching runtime.

---

### What Is Validated?

When the engine boots or a workflow is triggered, it checks:

| Checkpoint | What It Verifies |
|------------|------------------|
| `module.yaml` | Exists and is valid YAML |
| `name` field | Matches the folder name |
| `class` field | The Python class exists in the expected file |
| `methods` list | Each method is callable on the class |
| `input` args | (At runtime) match the method’s signature |

If anything is off, the workflow will be **rejected early**, with an informative log message.

---

### Example: Valid Slack Module

```yaml
# module.yaml
name: slack_module
class: Slack
methods:
  - send_info_message
  - send_incident_message
```

```python
# Slack.py
class Slack:
    def __init__(self, context):
        self.context = context

    def send_info_message(self, channel, title, message):
        ...

    def send_incident_message(self, channel, message, severity=None, oncall_user=None):
        ...
```

When a workflow references:
```yaml
action: slack_module.Slack.send_incident_message
```

The engine verifies:
- `modules/slack_module/` exists
- `slack.py` contains a class `Slack`
- That class has a method `send_incident_message`
- It’s listed in `module.yaml`

✅ If all passes — the step is executed normally.  
❌ If not — the workflow fails fast with a clear error.

---

### Common Validation Errors

| Error Message | Likely Cause |
|---------------|--------------|
| `Module folder not found` | Typo in the `action:` module name |
| `Class not found` | `class:` value doesn’t match actual class |
| `Method not found` | Method missing from `module.yaml` or not defined |
| `Invalid module.yaml` | Malformed YAML or missing keys |


---


# Koreflow Workflow DSL – Reference & Examples

---

## 1. DSL Structure Overview

A Koreflow workflow is defined in YAML under the top-level `workflow:` key.
For more in-depth DSL reference check docs/dsl.md file

```yaml
workflow:
  name: cert_provisioning

  match: {...}                  # Optional: match payload
  payload_parser: [...]         # Optional: extract vars from payload
  context_variables: [...]      # Optional: static or default values
  context_modules: {...}        # Optional: reusable module instances
  steps: [...]                  # Main logic steps
```

---

## 2. Top-Level Keys

### `name`
The name of the workflow.

---

### `match`
Conditionally runs workflow based on incoming payload.

```yaml
match:
  conditions:
    - path: payload.alert.severity
      operator: equals
      value: "critical"
      id: is_critical
  condition_logic: is_critical
```

---

### `payload_parser`
Extracts and maps values from payload into context.

```yaml
payload_parser:
  - path: payload.alert.source
    var: source
  - path: payload.user
    var: triggered_by
    absent_action: ignore
```

---

### `context_variables`
Declares variables used during execution.

```yaml
context_variables:
  - name: channel
    default: "#ops"
  - name: env
    default: "staging"
```

---

### `context_modules`
Instantiates long-lived modules (e.g. Git, Chatbot) once and reuses them.

```yaml
context_modules:
  git:
    module: git_module.Git
    repo: "https://github.com/org/repo.git"
    branch: "feature/{{ context.env }}"
    base_branch: "main"
    work_dir: "/tmp/gitops"
    handle_existing_branch: "pull"
```

---

## 3. Step Definition

Each step in `steps:` drives the workflow. The engine will run steps **in order**, optionally skipping based on `conditions`.

```yaml
steps:
  - id: send_slack
    type: action
    action: slack_module.Slack.send_info_message
    input:
      channel: "{{ context.channel }}"
      title: "Deployment started"
      message: "Triggered by {{ context.triggered_by }}"
```

---

## 4. Step Keys

| Key | Description |
|-----|-------------|
| `id` | Unique ID for step |
| `type` | One of: `action`, `approval`, `webform` |
| `action` | If `type: action`, points to `module.Class.method` |
| `input` | Dictionary passed as kwargs to method |
| `conditions` | (Optional) Determines whether step runs |
| `condition_logic` | Boolean logic for the conditions |
| `register_output` | Stores method result in context |
| `register_vars` | Defines new variables in context |
| `delivery_step` | Only for `approval`/`webform` – sends the approval link |

---

## 5. Common Workflow Patterns

---

### Alert → Notification → Auto Remediation

```yaml
- id: send_slack
  type: action
  action: slack_module.Slack.send_info_message
  input:
    channel: "#alerts"
    title: "⚠️ Critical Alert"
    keyed_message:
      - key: "Source"
        value: "{{ context.source }}"
      - key: "Env"
        value: "{{ context.env }}"

- id: restart_service
  type: action
  action: api_module.API.call
  input:
    method: "POST"
    url: "https://api.internal/restart"
    body:
      service: "nginx"
      env: "{{ context.env }}"
```

---

### CD with Manual Approval (Safe Deploy)

```yaml
- id: deploy_notification
  type: action
  action: slack_module.Slack.send_info_message
  input:
    channel: "{{ context.channel }}"
    title: "🟡 Ready to Deploy"
    message: "Click to approve: <{{ context.approval_link }}|Approve Deploy>"

- id: deploy_approval
  type: approval
  message: "Deploy to {{ context.env }}?"
  timeout_minutes: 120
  delivery_step: deploy_notification

- id: trigger_deploy
  type: action
  action: api_module.API.call
  input:
    method: "POST"
    url: "https://cd.system/deploy"
    body:
      env: "{{ context.env }}"
```

---

### Human-in-the-loop Certificate Provisioning

```yaml
- id: provision_form
  type: webform
  module: webform
  config_file: cert_form.js
  css_file: custom.css
  timeout_minutes: 120
  delivery_step:
    id: form_notify
    type: action
    action: slack_module.Slack.send_info_message
    input:
      channel: "#ssl-team"
      message: "Complete form: <{{ context.approval_link }}|Cert Request>"

- id: ask_chatbot
  type: action
  action: chatbot_module.Chatbot.ask
  input:
    provider: "openai"
    model: "gpt-4"
    system_prompt: "Summarize cert request."
    user_message: "{{ context.form_result | tojson }}"
    api_key: "{{ context.openai_key }}"

- id: notify_summary
  type: action
  action: slack_module.Slack.send_info_message
  input:
    channel: "#ssl-team"
    message: "{{ context.step_results.ask_chatbot.data.reply }}"
```

---

### Environment Creation with GitOps and Approval

```yaml
context_modules:
  git:
    module: git_module.Git
    repo: "https://github.com/org/envs.git"
    branch: "env-{{ context.user }}"
    base_branch: "main"
    work_dir: "/tmp/git-envs"
    handle_existing_branch: "fail"

steps:
  - id: render_env_file
    type: action
    action: context.git.add_file_from_template
    input:
      template: "env.yaml.j2"
      destination: "envs/{{ context.user }}/main.yaml"

  - id: open_pr
    type: action
    action: context.git.open_pr
    input:
      title: "Create env for {{ context.user }}"
      body: "Auto-generated"

  - id: approve_env
    type: approval
    message: "Approve env creation?"
    timeout_minutes: 60
    delivery_step:
      id: alert_env
      type: action
      action: slack_module.Slack.send_info_message
      input:
        channel: "#platform"
        message: "Approve PR: <{{ context.approval_link }}|View>"

  - id: merge_env
    type: action
    action: context.git.merge_pr
```

---

### Manual Gate + Conditional Execution

```yaml
- id: approval_step
  type: webform
  module: webform
  config_file: gate_form.js
  register_output: gate_data
  timeout_minutes: 30

- id: skip_if_denied
  type: action
  action: slack_module.Slack.send_info_message
  conditions:
    conditions:
      - path: context.gate_data.status.form_data.approval
        operator: not_equals
        value: "yes"
        id: is_denied
    condition_logic: is_denied
  input:
    message: "Gate not approved. Aborting."

- id: continue_if_approved
  type: action
  action: slack_module.Slack.send_info_message
  conditions:
    conditions:
      - path: context.gate_data.status.form_data.approval
        operator: equals
        value: "yes"
        id: is_approved
    condition_logic: is_approved
  input:
    message: "Gate approved. Continuing execution."
```

---

## Variable Access Patterns

You can access:

```yaml
context.form_result.status.form_data.key
context.approval_link
context.chatbot_reply.reply
context.git_pr_result.url
context.payload.alert.details
```

Use `context.step_results.<step id>` or `register_output` to capture the result of a step, and reference it later.


## Final Words

I built Koreflow around a philosophy of operational clarity, control, and composability. The engine was built to **solve real-world problems** that we face every day: duct-taped scripts, manual approvals, brittle integrations, jungle of custom scripts etc.

You need no coding expertise to define your workflows in YAML, but you have a framework or extending them with custom modules.
Koreflow gives you full control — **declarative, extensible, observable, testable**.  
It scales from the simplest Slack notifier to complex, stateful automations involving human input, approvals, and external systems.

You now have the framework.  
Use it to **productize your operations**, close the loop between people and automation, and build workflows that **make sense**.

I’d love to see this project grow and find its place in the community.
You're more than welcome to contribute — as long as your contributions honor the core philosophy.


Cheers!
Yuri


## Section 3: License

Koreflow is licensed under the GNU Affero General Public License v3.0 (AGPLv3).

If you use Koreflow or its derivatives in a commercial product or service (including SaaS), a revenue-sharing agreement applies. You must either:

- Open source your derived work under AGPLv3, or
- Contact the author to arrange a revenue share license.

See [LICENSE](./LICENSE/LICENSE) and [EULA](./LICENSE/EULA.md) for details.



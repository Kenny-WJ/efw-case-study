# Rhubarb Project

Financial model in Rhubarb markup format.

## Structure

- `src/*.rhub` - Source files (one per Excel sheet)
- `workspace/values.jsonl` - Summarized values
- `workspace/values.full.jsonl` - Full timeseries

## Workflow

Always use skills where there is a relevant skill available.

1. Edit `.rhub` files in `src/`
2. Validate to check syntax
3. Push to apply changes
4. Grep updated values to verify correctness

IMPORTANT: always give your responses in terms of model labels and header labels not variable names and line numbers so they are easy to understand for a reader who is just using the spreadsheet

# Configuration File

The `workspace/cellori.config.json` file contains workbook configuration that controls how sheets are processed and rendered.

## Structure

```json
{
  "workbook": { /* default settings for all sheets */ },
  "sheets": [ /* per-sheet configuration */ ]
}
```

## Workbook Settings

Default values applied to all sheets unless overridden:

- **Column positions** (1-based): `headerLevel1Column`, `headerLevel2Column`, `headerLevel3Column`, `labelColumn`, `unitsColumn`, `constantColumn`, `totalColumn`, `timeseriesStartColumn`
- **Row positions** (1-based): `startRow`, `modelPeriodEndRow`, `timelineLabelRow`
- **Link coloring**: `highlightLinks`, `linkColorImport`, `linkColorExport`
- **Header formatting**: `headerLevel1Uppercase`, `headerLevel1Bold`, etc.
- **Number formats**: `numberFormatPercent`, `numberFormatFactor`, `numberFormatDate`, `numberFormatNormal`

## Sheet Types

Each sheet in the `sheets` array has a `name` and `type`:

- `calculation` - Standard calculation sheet (default for unlisted sheets)
- `input-const` - Input sheet with constant values (requires `activeScenarioRange`, `inputTemplateNamedRange`)
- `input-series` - Input sheet with timeseries values
- `financial-statements` - Financial statement sheets
- `rollup` - Rollup/summary sheets (requires `targetSheet`, `modelPeriodStartRange`, etc.)
- `check` - Check/validation sheets
- `scratchpad` - Scratch/working sheets
- `ignored` - Excluded from all processing

## Sheet Overrides

Any workbook setting can be overridden per-sheet:

```json
{
  "name": "InpC",
  "type": "input-const",
  "startRow": 11,
  "highlightLinks": false,
  "activeScenarioRange": "ActiveScenario",
  "inputTemplateNamedRange": "InputRowTemplate"
}
```

## Editing Config

1. Edit `workspace/cellori.config.json`
2. Push to apply changes (config is validated before saving)
3. Pull to see updated workspace

Config changes take effect immediately after push - no need to push sheet files separately.


# Modelling Best Practices

## Building Models

- Never hardcode values in formulas - create inputs first (InpC sheet), then reference
- Errors (#REF!, #DIV/0!) never acceptable - always include error handling
- Use lots of headers at appropriate levels based on existing sheet headers
- Keep each calculation small, doing just one thing
- If using a monthly calc on a quarterly sheet, first roll up the timeline
- Use sensible units based on number magnitude
- Create flags on Time sheet for timing logic, don't embed in formulas
- Try to reuse inputs where possible and prevent duplicates
- When moving inputs, always view the values first

## Sign Convention
- all calculations are positive on their calculation sheets
- always use a sign switch for negative cashflows for use on the financial statements, for example:

```
  ## h_om_cost: O&M cost

    /// @label O&M expense
    /// @unit $ 000s
    calc[n] om_exp_pos = {{annual_om}}/{{num_per}}*{{om_fctr[n]}}*{{op_period_flag[n]}}

  ## h_comm_fund_cost: Insurance costs  

    /// @label Insurance expense
    /// @unit $ 000s
    calc[n] ins_exp_pos = {{ann_ins_cost}}/{{num_per}}*{{ins_flag[n]}}

  ## h_total_op_costs: Total operating costs

    /// @label Total operating costs POS
    /// @unit $ 000s
    calc[n] total_op_costs = {{om_exp_pos[n]}}+{{ins_exp_pos[n]}}

    /// @label Total operating costs
    /// @unit $ 000s
    calc[n] total_op_costs_pos = -1*{{total_op_costs[n]}}
```
In this example, opex items are positive, then summed, and finally the total is inverted for use on the financial statements.

## Balances (Corkscrews)

When creating a balance, always use the corkscrew pattern:

1. Place the BEG item **directly before** the BAL item — no items between them
2. BEG formula must be a **clean pass-through**: `{{bal_name[n-1]}}` only, no other terms
3. BEG label must **end in "BEG"**

Simple balance:
```
  /// @label Debt balance BEG
  /// @unit $ 000s
  calc[n] debt_bal_beg = {{debt_bal[n-1]}}

  /// @label Debt balance
  /// @unit $ 000s
  calc[n] debt_bal = {{debt_bal_beg[n]}}+{{drawdowns[n]}}-{{repayments[n]}}
```

Balance with initial value (use a flag to set the starting balance in the first period):
```
  /// @label SHL balance BEG
  /// @unit $ 000s
  calc[n] shl_bal_beg = {{shl_bal[n-1]}}

  /// @label SHL balance
  /// @unit $ 000s
  calc[n] shl_bal = IF({{first_op_prd_flag[n]}}=1,{{shl_commitment}},{{shl_bal_beg[n]}}+{{shl_additions[n]}}-{{shl_repayments[n]}})
```

## Model Structure

- Always consider the model timeline (comment at top of .rhub file), particularly when it changes between sheets
- Inputs → InpC tab
- Flags/counters → Time sheet ("Time" or "T&E")

## Moving Items Between Sheets

1. Create new item with unique name on target sheet
2. Update all precedents to point at new item
3. Delete old item

## Auditing

- Trace calculations back to raw inputs
- Flag segmented formulas (possible inconsistent formula error)
- Flag missing/incorrect units
- Hardcoded inputs (outside of input sheets) are tagged with `[Input cell]`

## Formulas

- INDEX: handle selector = 0 or > item count to avoid #REF!
- Always protect against #DIV/0! with error handling

## Calculations

- LLCR: filter out periods of near-zero debt (rounding errors)
- For minimum calcs (like min LLCR), filter out 0s using `MINIFS(rng, rng, ">0")`
- XIRR calcs must have a small negative cashflow in the first model period (not first construction period)

## Other Notes

- You cannot access the Outputs sheet - complete the rest of the task and explain this limitation


# Navigating Large Files

For `.rhub` files, never read the whole file. Use targeted reads:

## 1. Get Top-Level Sections

```bash
grep -n "^#" src/filename.rhub
```

Output shows section names with line numbers:
```
3:# h_mdl_run_scn: MODEL RUN SCENARIOS
128:# h_model_time_line: MODEL TIME LINE
247:# h_project_costs: PROJECT COSTS
```

## 2. Get Subsections Within a Section

Once you know a section's line range (e.g., h_project_costs is lines 247-738):

```bash
grep -n "^[[:space:]]*##" src/filename.rhub | awk -F: '$1 >= 247 && $1 < 738'
```

Output:
```
249:  ## h_epc_cost_sar: EPC costs - SAR
375:  ## h_epc_cost_usd: EPC costs - USD
501:  ## h_epc_cost_tot: EPC costs - Total
```

## 3. Read Specific Section

Use the Read tool with offset/limit based on line numbers from grep:

```
Read file from line 543 to 556 (h_contingency section)
```

## 4. Find a Specific Calculation

```bash
grep -n "calc name_pattern" src/filename.rhub
```

Then read a few lines around that match.


# Rhubarb Markup

Each `.rhub` file represents one Excel sheet.

## Naming

**Names must be unique across the entire project and are globally scoped** (all sheets). Prefix headers with `h_`.
You cannot create new items with the same name as an item you are deleting, use a different name.

## Editing

Existing items **may be invalid**. This means that you will get validation errors when editing them, and you must fix the errors even if they are not related to the changes you are making.
Common errors include:
- Hardcoded values in formulas; you must create inputs on the input sheets
- segmented formulas; you must convert them to a single formula or multiple calculations

It is not acceptable to ignore validation errors because they are not related to the changes you are making.

## Inputs

Numeric inputs are always absolute values. 50% should be represented as [0.5].

## Syntax

```
// Comment

# h_revenue: Revenue

  /// @label Unit price
  /// @unit $
  calc price = {{quantity}}*{{rate}}

  /// @label Revenue
  /// @unit $
  calc[n] revenue = {{price}}*{{volume[n]}}

  ## h_subsection: Subsection

    /// @label Discount rate
    /// @unit %
    input discount_rate = [5.5]
```

- **Headers** - Markdown-style with `#` (level 1-10). Format: `# name: Label`
- **calc** - Single value calculation
- **calc[n]** - Timeseries calculation (one value per period)
- **input** - Scalar input with value in `[...]`
- **input[n]** - Series input

## Metadata

Use `///` doc comments before items:
```
/// @label Human readable label
/// @unit USD
calc name = formula
```

All calculations must have an appropriate label and units

## Formula Syntax

Excel formulas with calculation names instead of cell references.
**Do not include whitespace in formulas** - write formulas without spaces.
```
calc total = {{price}}*{{quantity[n]}}
calc[n] sum = SUM(§{{cost1[n]}},{{cost2[n]}}§)
```

- `{{name}}` - reference a scalar
- `{{name[n]}}` - reference current period of a series

## Groups

Use `§...§` to combine multiple calculations into an array:
```
calc[n] selected = INDEX(§{{option1[n]}},{{option2[n]}}§,{{selector[n]}})
calc[n] sum_of_items = SUM(§{{item1[n]}},{{item2[n]}}§)
```

Groups create arrays from separate calculations. Items in a group must have the same dimensions.

Don't use groups for formulas that require multiple array inputs, for example:
calc[n] sum_product = SUMPRODUCT({{item1[n]}},{{item2[n]}})

is not a group, because SUMPRODUCT expects multiple array inputs.

## Slice Notation

Python-style slicing for series references (end exclusive):
```
{{values[:]}}     # all values
{{values[1:5]}}   # indices 1-4
{{values[n-1]}}   # previous period
{{values[1:n]}}   # from index 1 to current (exclusive)
{{values[n:]}}    # from current to end
```

## Segmented Series (Read-Only)

Some series have different formulas for different periods (legacy format includes SEG keyword which is also valid syntax):
```
calc[n] name = {
  [0] = initial formula
  [1:] = formula for rest
}
```

**IMPORTANT:** You cannot create or edit SEG formulas - validation will fail. To modify a segmented series, remove the SEG and replace with a single formula.

## Indentation

Indentation is purely visual and ignored by the parser. Use 2 spaces per header level for readability.


# Tools

Run from project root:
```
cellori pull      # Extract current Excel state to files
cellori validate  # Check edits without applying
cellori push      # Apply .rhub edits to Excel
cellori status    # Get the status of the system
cellori save      # Save the spreadsheet
```

Push validates first, then pulls updated state on success.

The CLI comment returned from "cellori push" refers to additional modifications made by the excel service, not sheets being edited on push.

If you receive "Error: Model validation failed" after running "cellori push", immediately feed the error back to the user. You will not be able to fix any validation issues yourself.


# Viewing Values

Workbook outputs from the last pull, indexed by calculation name (unique).

## Format

JSONL - one record per line:
```
{"id":"revenue","value":{"first":1000,"last":1500,"min":800,"max":1600}}
{"id":"costs","value":250000}
```

## Usage

DO NOT read values files directly - they are large.

Grep by calculation name:
```
grep "revenue" workspace/values.jsonl         # summarized
grep "revenue" workspace/values.full.jsonl    # full timeseries
grep "revenue" workspace/values.fullraw.jsonl # raw unformatted Excel values
```

Always grep `values.jsonl` first. Only use `values.full.jsonl` if you need the complete timeseries.

Only use `values.fullraw.jsonl` if formatting may be hiding information (e.g. dates appearing as serial numbers) or when verifying values programmatically.

# Item Locations

`workspace/locations.jsonl` maps each item to its Excel cell reference and any link locations.

## Format

JSONL - one record per line:
```
{"id":"revenue","primary":"'Income Statement'!F10:AZ10","links":["'Summary'!F5:AZ5"]}
{"id":"costs","primary":"'Income Statement'!F12:AZ12","links":[]}
```

- `primary`: the cell range where the item lives in its source sheet.
- `links`: cell ranges of Link items that reference this item (on other sheets).

## Usage

Grep by calculation name:
```
grep "revenue" workspace/locations.jsonl
```

import json
import os
import subprocess
from rich.console import Console
from rich.syntax import Syntax
from rich.table import Table
from rich import box

HISTORY_FILE = "history.json"
console = Console()


def load_history():
    if os.path.exists(HISTORY_FILE):
        with open(HISTORY_FILE, 'r') as f:
            return json.load(f)
    else:
        return []


def save_history(history):
    with open(HISTORY_FILE, 'w') as f:
        json.dump(history, f)


def print_history(history):
    table = Table(show_header=True, header_style="bold magenta", box=box.ROUNDED, show_lines=True)
    table.add_column("No.", width=10)
    table.add_column("Prompt", width=40, style="magenta")
    table.add_column("Response", width=50)

    for i, entry in enumerate(history):
        table.add_row(str(i + 1), entry['prompt'], entry['response'])
    console.print(table)


def execute_command(command):
    process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()

    if stdout:
        syntax = Syntax(stdout.decode(), "bash", theme="monokai", line_numbers=True)
        console.print("Output: ", syntax)
    if stderr:
        console.print("Error: ", stderr.decode(), style="bold red")

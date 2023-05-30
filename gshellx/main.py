import click

from .openai_api import raise_exception_if_no_key, request_to_completions
from .prompts import command_generation_prompt
from .shell_utils import load_history, save_history, print_history, execute_command
from rich.console import Console
from rich.syntax import Syntax
from threading import Thread, Event
from prompt_toolkit import prompt as prmt

raise_exception_if_no_key()
console = Console()

stop_spinner = Event()


def spin():
    with console.status("[bold green]Processing..."):
        while not stop_spinner.wait(timeout=0.1):
            pass


@click.command()
@click.option('--prompt', '-p', default=None, help='Prompt for ChatGPT')
@click.option('--cmd', '-c', default=None, help='Command to execute.')
@click.option('--interactive', '-i', is_flag=True, help='Run in interactive mode.')
def main(prompt, cmd, interactive):
    history = load_history()

    if prompt:
        process_other_prompt(prompt, history)
        save_history(history)

    if cmd:
        process_command_prompt(cmd, command_generation_prompt, history)
        save_history(history)
        return

    if interactive:
        running = True
        while running:
            prompt = get_prompt()

            if prompt == 'exit' or prompt == 'q':
                running = False
                continue

            if prompt == 'history':
                print_history(history)
            elif prompt.strip().startswith('command:'):
                process_command_prompt(prompt, command_generation_prompt, history)
            else:
                process_other_prompt(prompt, history)

            save_history(history)


def get_prompt():
    console.print("\nEnter a prompt: ", end="", style="bold cyan")
    return input()


def process_command_prompt(prompt, command_generation_prompt, history):
    request_prompt = command_generation_prompt + prompt.replace('command:', '', 1)

    spinner_thread = Thread(target=spin)
    spinner_thread.start()

    response = request_to_completions(request_prompt)

    stop_spinner.set()
    spinner_thread.join()
    stop_spinner.clear()

    console.print(f"\nThe command is: {response}\n", style="bold green")
    execute = input("Do you want to execute this command? (y/n) or edit (e): ")

    if execute.lower() == 'e':
        response = prmt('Enter your edited command: ', default=response)
        console.print(f"\nThe command is: {response}", style="bold green")
        execute = input("Do you want to execute this command? (y/n) or edit (e): ")

    if execute.lower() == 'y':
        execute_command(response)

    history.append({
        'prompt': prompt,
        'response': response
    })


def process_other_prompt(prompt, history):
    spinner_thread = Thread(target=spin)
    spinner_thread.start()

    response = request_to_completions(prompt)

    stop_spinner.set()
    spinner_thread.join()
    stop_spinner.clear()

    code_block_wrapper = '```'

    if code_block_wrapper in response:
        start = response.index(code_block_wrapper) + 3
        end = response.index(code_block_wrapper, start)
        code = response[start:end]
        syntax = Syntax(code, "python", theme="monokai", line_numbers=False)
        console.print(response[:start - 3])
        console.print(syntax)
        console.print(response[end + 3:])
    else:
        console.print(f"{response}", style="bold green")

    history.append({
        'prompt': prompt,
        'response': response
    })


if __name__ == "__main__":
    main()

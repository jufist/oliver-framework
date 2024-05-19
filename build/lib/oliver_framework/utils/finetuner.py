import os
import json
import sys

# Add the parent directory of the 'utils' directory to the module search path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from utils.logging import getlogger
logger=getlogger("finetunes")

class Finetuner:
    def __init__(self, input_string):
        self.input_string = input_string

    def clean0(self, length):
        # Check if the input_string has at least 'length' characters
        if len(self.input_string) >= length:
            # Get the portion of the string without the specific '0's at the end
            if self.input_string[-length:] == '0' * length:
                self.input_string = self.input_string[:-length]
        return self

    def thousand(self):
        self.float(1000)
        return self

    def substr(self, start, length, remove=""):
        value = self.input_string 

        # Remove special chars
        if remove:
            value = value.replace(remove, "")

            # Hard code fix for date
            if remove == "/":
                value = value.replace("-", "")

        if len(value) >= length:
            value = value[start:length+start]
        self.input_string = value
        return self

    def leading0(self, length):
        value = self.input_string 
        if len(value) <= length:
            value = value.zfill(length)
        self.input_string = value
        return self

    def hourly(self):
        value = self.input_string
        
        # Split the value string using ":"
        hh, mm, ss = map(int, value.split(':'))

        # Calculate total hours with three decimal places
        total_hours = hh + mm / 60 + ss / 3600

        # Convert the result to a string with three decimal places
        self.input_string = f"{total_hours:.3f}"

        # Make it to float
        self.float()

        return self

    def float(self, divide = 1):
        try:
            updated_value = float(self.input_string) / divide
        except ValueError:
            # logger.error(f"{value} is not INT")
            updated_value = self.input_string
        self.input_string = updated_value

        return self

    def int(self, divide = 1):
        value = self.input_string 
        updated_value = value

        # If E in value like 2.02308E+13 Do convert to INT first
        if 'E' in str(value):
            try:
                updated_value = int(float(value))
                value = updated_value
            except ValueError:
                pass

        try:
            updated_value = int(float(value) / divide)
        except ValueError:
            # logger.error(f"{value} is not INT")
            updated_value = self.input_string
        self.input_string = updated_value

        return self

    def blank(self):
        value = self.input_string 
        if value == "0" or value == "-1" or value == "":
            self.input_string = ""

        return self

    def datetime(self):
        value = self.input_string 
        updated_value = value

        # If E in value like 2.02308E+13 Do convert to INT first
        if 'E' in value:
            try:
                updated_value = str(int(float(value)))
                value = updated_value
            except ValueError:
                pass

        if "/" not in value and "-" not in value and 4 <= len(value) < 14:
          value = value.ljust(14, '0')

        # if value is in format yyyymmddhhmmss then convert to yyyy/mm/dd hh:mm:ss
        if len(value) == 14:
            updated_value = f"{value[0:4]}/{value[4:6]}/{value[6:8]} {value[8:10]}:{value[10:12]}:{value[12:14]}"

        # Correct 0:00:00
        if '/' in value and ' ' in value and ':' in value:
            date_part, time_part = value.split(' ')
            if len(time_part) == 7:
                time_part = '0' + time_part
            updated_value = f"{date_part} {time_part}"

        self.input_string = updated_value

        return self

    def time(self):
        value = self.input_string 

        if 0 <= len(value) <= 5:
            value = value.zfill(6)

        # if value is in format hhmmss then convert to hh:mm:ss
        if len(value) == 6:
            value  = f"{value[0:2]}:{value[2:4]}:{value[4:6]}"

        self.input_string = value

        return self

    def date(self):
        value = self.input_string 

        # Remove ' 0:00:00' out of the right of value
        if ' ' in value:
          value = value.split(' ')[0]

        # If length of value is less than 8 and greater than 6 then add 0 as prefix padding
        if 6 < len(value) < 8:
          value = value.zfill(8)

        # if value is in format yyyymmdd then convert to yyyy-mm-dd
        updated_value = value
        if len(value) == 8:
            updated_value = f"{value[0:4]}-{value[4:6]}-{value[6:8]}"

        self.input_string = updated_value

        return self

    def hundred(self):
        self.float(100)
        return self

    def decade(self):
        self.float(10)
        return self

    def finetune(self, finetunes):
        # Split the finetunes string by "|"
        finetune_operations = finetunes.split('|')
        
        # Loop through each finetune operation and apply it to the input string using eval
        for operation in finetune_operations:
            if not operation:
                continue
            try:
                # Split the operation string by comma to separate the method name and arguments
                parts = operation.split(',')
                
                # Extract the method name and arguments
                method_name = parts[0].strip()
                if len(parts) > 1:
                    arguments = parts[1].strip().split('~')
                else:
                    arguments = []

                # Construct the eval statement with method name and arguments
                args = ', '.join(arguments)
                eval_statement = f"self.{method_name}({args})"

                # Execute the eval statement
                eval(eval_statement)
            except Exception as e:
                # Handle invalid operations
                logger.error(f"Invalid operation: {method_name},{arguments}~{self.input_string}. {e}")
        
        return self.input_string

    def __str__(self):
        return self.input_string

import logging
import os
import colorlog
import random
import datetime
from dotenv import load_dotenv

env_path = os.getcwd() + '/.env'
# Configure the logger with common settings
load_dotenv(env_path)
log_level = os.getenv('LOGGINGLEVEL', 'INFO')
logging.basicConfig(
    level=log_level,
    format='%(asctime)s - [%(levelname)s] - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

# Create a logger instance
logger = colorlog.getLogger()
# logger = logging.getLogger("logging")

class Logger:
    # Store color map for departments
    department_colors = {}
    gui_log = os.path.join("logs", "gui.log")

    def set_log_file(log_file):
       gui_log = log_file
    
    def __init__(self, department):
        self.department = department
        self.extra = {'department': self.department}
        self.prefix = f"[{department}] "
        
        # Set the color for the department if not already set
        if department not in Logger.department_colors:
            Logger.department_colors[department] = {
                'DEBUG': 'purple',
                'INFO': 'green',
                'WARNING': 'yellow',
                'ERROR': 'red',
                'CRITICAL': 'red',
            }
        
        # Set up colorlog's formatter and handler
        self.update_color()
        
    def add_handler(self, handler):
        logger.addHandler(handler)

    def update_color(self):
        formatter = colorlog.ColoredFormatter(
            '%(log_color)s%(asctime)s - [%(levelname)s] - %(message)s%(reset)s',
            datefmt='%Y-%m-%d %H:%M:%S',
            log_colors=Logger.department_colors[self.department],
            reset=True,
            style='%'
        )
        handler = logging.StreamHandler()
        handler.setFormatter(formatter)
        
        ##  Clear existing handlers and set the new handler
        logger.handlers[0] = handler
        
    def get_random_color(self):
        colors = ['black, bg_white', 'red', 'green', 'yellow', 'blue', 'purple', 'cyan, bg_white']
        color = random.choice(colors)
        return color
    
    def debug(self, msg, *args):
        self.update_color()
        logger.debug(f"{self.prefix}{msg}{args if len(args) else ''}", extra=self.extra)
        
    def to_log(self, msg, *args):
        # Try to open and write and close right away for other processes to work on this file
        try:
            with open(gui_log, "a") as file:
                current_time = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                file.write(f"{current_time} {msg} {args}\n")
                # os.fsync(file.fileno())  # Flush the file buffer and force it to be written to disk
        except OSError as e:
            self.warning(f"Error opening or writing to gui.log: {e}")

    def info(self, msg, *args):
        msg=f"{self.prefix}{msg}{args if len(args) else ''}"
        self.update_color()
        self.to_log(msg, *args)
        logger.info(msg, extra=self.extra)
        
    def warning(self, msg, *args):
        self.update_color()
        self.to_log(msg, *args)
        logger.warning(f"{self.prefix}{msg}{args if len(args) else ''}", extra=self.extra)
        
    def error(self, msg, *args):
        self.update_color()
        self.to_log(msg, *args)
        logger.error(f"{self.prefix}{msg}{args if len(args) else ''}", extra=self.extra)

    def critical(self, msg, *args):
        self.update_color()
        logger.critical(f"{self.prefix}{msg}{args if len(args) else ''}", extra=self.extra)

# Create other department loggers
def getlogger(department):
    return Logger(department)

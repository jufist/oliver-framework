import pyodbc
import configparser
import os
import json
from utils.logging import getlogger
logger=getlogger("database")

from datetime import datetime, date, time
from decimal import Decimal
import time as mod_time
from includes.common import load_env
from includes.common import json_load

import sqlparse

debug_nodb = load_env("DEBUG_NODB")
debug_prettyquery = load_env("DEBUG_PRETTYQUERY")

class Database:
    def __init__(self, config_file):
        self.config_file = config_file
        self.config = self.read_config()
        self.connection_string = self.create_connection_string()
        self.sample = None

    def use_sample(self, sample, sampleinfo = ""): 
        self.sample = sample
        self.sampleinfo = sampleinfo

    def tail(self):
        return self.log

    def read_config(self):
        config = configparser.ConfigParser()
        config.read(self.config_file)
        return config['DATABASE']

    def create_connection_string(self):
        db_config = self.config
        connection_string = f"Driver={{ODBC Driver 17 for SQL Server}};Server={db_config['server']};Database={db_config['database']};Uid={db_config['username']};Pwd={db_config['password']};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;CHARSET=UTF8;"
        return connection_string

    def connect(self):
        try:
            # Attempt to establish the database connection
            connection = pyodbc.connect(self.connection_string)
            return connection
        except pyodbc.Error as e:
            # If the connection is not successful, raise an error with the connection string
            raise ConnectionError(f"Connection to the database failed. Connection string: {self.connection_string}") from e

    def execute_procedure(self, procedure_name, *args):
        connection = self.connect()
        cursor = connection.cursor()
        cursor.execute(f"EXEC {procedure_name} {', '.join(map(str, args))}")
        results = cursor.fetchall()
        connection.close()
        return results

    def execute_query(self, query, dict=False, *args):
        return self.execute_query_retry(query, dict, 3, 1, *args)

    def execute_query_retry(self, query, dict=False, max_retries=3, retry_interval=1, *args):
        for retry in range(max_retries + 1):
            try:
                if debug_prettyquery:
                    # Building the query prettier
                    pretty_args = [repr(arg) for arg in args]  # Represent each arg as a string
                    pretty_query = query
                    for arg in pretty_args:
                        pretty_query = pretty_query.replace("?", arg, 1)  # Replace each '?' with an argument
                    formatted_query = sqlparse.format(pretty_query, reindent=True, keyword_case='upper')
                    self.log = f"\n{formatted_query}"
                else:
                    self.log=(query + "~" + " ".join([f"{item}" for item in args])).replace("\n", " ")
                logger.debug(self.log)
                if debug_nodb:
                    sample = self.sample
                    self.sample = None
                    if sample:
                        logger.debug(f"Returning sample {self.sampleinfo} and not executing any query because DEBUG_NODB={debug_nodb}")
                        return sample
                    logger.debug(f"Returning False/None and not executing any query because DEBUG_NODB={debug_nodb}")
                    return None

                connection = self.connect()
                cursor = connection.cursor()
                if query.strip().lower().startswith("select"):
                    cursor.execute(query, args)
                    if dict:
                        column_names = [column[0] for column in cursor.description]
                        results = []
                        # Loop for all row in results and assign proper to newresults variables
                        for row in cursor.fetchall():
                            new_row = {}
                            for i, column_name in enumerate(column_names):
                                column_value = row[i]

                                # Convert None to empty string
                                if column_value is None:
                                    new_row[column_name] = ""
                                # Convert date to string format
                                elif isinstance(column_value, date):
                                    new_row[column_name] = column_value.strftime("%Y-%m-%d")
                                # Convert time to string format
                                elif isinstance(column_value, time):
                                    new_row[column_name] = column_value.strftime("%H:%M:%S")
                                # Convert datetime to string format
                                elif isinstance(column_value, datetime):
                                    new_row[column_name] = column_value.strftime("%Y-%m-%d %H:%M:%S")
                                elif isinstance(column_value, Decimal):
                                    new_row[column_name] = str(column_value)
                                # Convert int and float to string
                                # elif isinstance(column_value, (int, float)):
                                #    new_row[column_name] = str(column_value)
                                else:
                                    new_row[column_name] = column_value

                            results.append(new_row)
                    else:
                        results = cursor.fetchall()
                else:
                    cursor.execute(query, args)
                    connection.commit()
                    results = None

                connection.close()
                return results
            except Exception as e:
                is_connection = "Error code 0x68" in f"{e}"
                # Should catch the connection issue only
                if not is_connection or retry >= max_retries:
                    raise e
                # Disconnect before retrying
                try:
                    connection.close()
                except:
                    pass  # Ignoring any exception while closing connection
                logger.warning(f"Query execution failed: {e}")
                logger.warning(f"Retrying in {retry_interval} seconds...")
                mod_time.sleep(retry_interval)

    def ensure_table_columns(self, table_name, json_file_path):
        columns_data = json_load(json_file_path)

        # Check if table exists
        result = self.execute_query(f"SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = '{table_name}'")
        if not (result and result[0][0]):
            # Create the table if it doesn't exist
            create_table_query = f"CREATE TABLE {table_name} ("
            columns = []
            for column_data in columns_data:
                column_name = column_data['name']
                column_type = column_data['type']
                columns.append(f"{column_name} {column_type}")
            create_table_query += ", ".join(columns) + ")"
            self.execute_query(create_table_query)

        else:
            # Table exists, check and modify columns if necessary
            existing_columns = self.execute_query(f"SELECT COLUMN_NAME, DATA_TYPE, CASE WHEN DATA_TYPE = 'DECIMAL' THEN CAST(NUMERIC_PRECISION AS VARCHAR(10)) + ',' + CAST(NUMERIC_SCALE AS VARCHAR(10)) ELSE CAST(CHARACTER_MAXIMUM_LENGTH AS VARCHAR(10)) END AS DATA_LENGTH FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '{table_name}'")

            existing_column_names = [column[0] for column in existing_columns]

            for column_data in columns_data:
                column_name = column_data['name']
                column_type = column_data['type']

                if column_name not in existing_column_names:
                    # New column, add it to the table
                    add_column_query = f"ALTER TABLE {table_name} ADD {column_name} {column_type}"
                    self.execute_query(add_column_query)

                else:
                    # Existing column, check data type and modify if necessary
                    existing_column_simple_type = [column[1] for column in existing_columns if column[0] == column_name][0]
                    existing_column_length = [column[2] for column in existing_columns if column[0] == column_name][0]
                    existing_column_type = f"{existing_column_simple_type}({existing_column_length})" if existing_column_length else f"{existing_column_simple_type}"

                    if column_type.lower() != existing_column_type.lower():
                        modify_column_query = f"ALTER TABLE {table_name} ALTER COLUMN {column_name} {column_type}"
                        self.execute_query(modify_column_query)



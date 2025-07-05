from pymongo import MongoClient
from datetime import datetime, timedelta
from typing import Dict, Any, List
import pandas as pd
from collections import deque

class MongoDB:
    def __init__(self):
        try:
            self.client = MongoClient('mongodb://localhost:27017/', serverSelectionTimeoutMS=5000)
            # Test the connection
            self.client.server_info()
            self.db = self.client['smart_trash']
            
            # Collections
            self.bins_history = self.db['bins_history']
            self.bins_current = self.db['bins_current']
            
            # Create indexes for better query performance
            self.bins_history.create_index([("bin_id", 1), ("timestamp", 1)])
            self.bins_history.create_index([("trash_type", 1)])
            self.bins_history.create_index([("trash_level", 1)])
            self.bins_current.create_index([("bin_id", 1)], unique=True)
            print("Successfully connected to MongoDB")
            
        except Exception as e:
            print(f"Error connecting to MongoDB: {e}")
            print("Make sure MongoDB is installed and running")
            raise

    def store_bin_data(self, bin_id: str, data: Dict[str, Any]):
        """Store bin data in both historical and current collections"""
        timestamp = datetime.now()
        
        # Prepare document
        history_doc = {
            'bin_id': bin_id,
            'timestamp': timestamp,
            **data
        }
        
        # Store in history
        self.bins_history.insert_one(history_doc)
        
        # Update current state
        self.bins_current.update_one(
            {'bin_id': bin_id},
            {'$set': {'timestamp': timestamp, **data}},
            upsert=True
        )
    
    def get_large_dataset(self, pipeline):
        """Use MongoDB aggregation for large datasets"""
        return self.db.bins_history.aggregate(pipeline, allowDiskUse=True)

    def get_last_7_temp_humidity_per_bin(self):
        """
        Return last 7 records of temperature and humidity for each bin as a DataFrame:
        columns: ['time', 'temp', 'rhum']
        """
        pipeline = [
            {"$sort": {"bin_id": 1, "timestamp": -1}},
            {"$group": {
                "_id": "$bin_id",
                "records": {
                    "$push": {
                        "timestamp": "$timestamp",
                        "temperature": "$temperature",
                        "humidity": "$humidity"
                    }
                }
            }},
            {"$project": {
                "records": {"$slice": ["$records", 7]}
            }}
        ]
        results = list(self.bins_history.aggregate(pipeline))
        bins = {}
        for doc in results:
            bin_id = doc["_id"]
            records = list(reversed(doc["records"]))  # chronological order
            # Build DataFrame with required columns and rename
            df = pd.DataFrame(records)
            if not df.empty:
                df = df.rename(columns={
                    "timestamp": "time",
                    "temperature": "temp",
                    "humidity": "rhum"
                })
                # Ensure correct column order
                df = df[["time", "temp", "rhum"]]
            bins[bin_id] = df
        return bins

    def get_all_data(self):
        """
        Return all historical bin data as a list of dicts.
        """
        return list(self.bins_history.find({}, {'_id': 0}))
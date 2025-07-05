from firebase_admin import messaging, db
from others.models import TrashData, GasLevelBin, GAS_LEVEL_BINS
from utils.constants import TRASH_FULL_THRESHOLD
from utils.constants import FCM_TOPIC

# --- Firebase Notification Service ---
class NotificationService:
    def __init__(self, db_mongo):
        self.db_mongo = db_mongo
        self.last_known_trash_levels = {}
        self.last_known_gas_levels = {}  # Add this line

    def send_fcm_notification(self, bin_id: str, bin_data: TrashData):
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=f"Trash Bin Alert: {bin_data.name}",
                    body=f"Bin '{bin_data.name}' is {bin_data.trash_level:.1f}% full. Needs emptying!",
                ),
                data={
                    "binId": str(bin_id),
                    "binName": str(bin_data.name),
                    "trashLevel": f"{bin_data.trash_level:.1f}",
                    "humidity": f"{bin_data.humidity:.1f}",
                    "gazLevel": f"{bin_data.gaz_level:.1f}",
                    "temperature": f"{bin_data.temperature:.1f}",
                    "latitude": f"{bin_data.location.latitude:.6f}",
                    "longitude": f"{bin_data.location.longitude:.6f}",
                    "trashType": str(bin_data.trash_type),
                    "weight": f"{bin_data.weight:.1f}",
                    "screen": "home",
                },
                topic=FCM_TOPIC,
            )
            response = messaging.send(message)
            print(f"Successfully sent FCM notification for '{bin_data.name}': {response}")
        except Exception as e:
            print(f"Error sending FCM message for bin '{bin_id}': {e}")

    def _process_bin_data(self, bin_id: str, bin_data: TrashData):
        # Process trash level alerts
        if bin_data.trash_level >= TRASH_FULL_THRESHOLD:
            if not self._should_send_notification(bin_id, bin_data.trash_level):
                return
            
            print(f"Trash bin '{bin_data.name}' (ID: {bin_id}) is {bin_data.trash_level:.1f}% full.")
            self.send_fcm_notification(bin_id, bin_data)
            self.last_known_trash_levels[bin_id] = bin_data.trash_level
        
        # Process gas level alerts
        self._check_gas_level(bin_id, bin_data)

    def _check_gas_level(self, bin_id: str, bin_data: TrashData):
        # gas level is (0-20)
        niveau = int(bin_data.gaz_level)

        # Only send new notification if gas level changed significantly
        if bin_id in self.last_known_gas_levels:
            old_niveau = self.last_known_gas_levels[bin_id]
            if old_niveau == niveau:
                return

        # Find appropriate gas bin info
        for gas_bin in GAS_LEVEL_BINS:
            if gas_bin.min_niveau <= niveau <= gas_bin.max_niveau:
                # Only send notifications for alert levels (niveau >= 5)
                if gas_bin.min_niveau >= 15:  # Start sending alerts from niveau 14
                    self.send_gas_notification(bin_id, bin_data, gas_bin)
                    print(f"Gas Alert - Bin: {bin_data.name}, Level: {niveau}, Message: {gas_bin.message}")
                self.last_known_gas_levels[bin_id] = niveau
                break

    def send_gas_notification(self, bin_id: str, bin_data: TrashData, gas_info: GasLevelBin):
        try:
            # Create notification message based on gas level severity
            message = messaging.Message(
                notification=messaging.Notification(
                    title=f"Gas Alert: {bin_data.name}",
                    body=gas_info.message,
                ),
                data={
                    "binId": str(bin_id),
                    "binName": str(bin_data.name),
                    "gasLevel": str(bin_data.gaz_level),
                    "message": gas_info.message,
                    "recommendation": gas_info.recommendation or "",
                    "recommendation1": gas_info.recommendation_1 or "",
                    "recommendation2": gas_info.recommendation_2 or "",
                    "latitude": f"{bin_data.location.latitude:.6f}",
                    "longitude": f"{bin_data.location.longitude:.6f}",
                    "screen": "gas_alert",
                    "severity": str(len([b for b in GAS_LEVEL_BINS if b.min_niveau <= gas_info.min_niveau]))
                },
                topic=f"{FCM_TOPIC}_gas",  # Separate topic for gas alerts
            )
            
            response = messaging.send(message)
            print(f"Successfully sent gas alert for '{bin_data.name}': {response}")
            
            # For critical levels (niveau >= 17), send to emergency topic
            if gas_info.min_niveau >= 17:
                emergency_message = messaging.Message(
                    notification=messaging.Notification(
                        title="🚨 CRITICAL GAS LEVEL EMERGENCY 🚨",
                        body=f"Critical gas levels detected at {bin_data.name}!"
                    ),
                    data={
                        "binId": str(bin_id),
                        "binName": str(bin_data.name),
                        "gasLevel": str(bin_data.gaz_level),
                        "latitude": f"{bin_data.location.latitude:.6f}",
                        "longitude": f"{bin_data.location.longitude:.6f}",
                        "screen": "emergency",
                    },
                    topic=f"{FCM_TOPIC}_emergency"
                )
                messaging.send(emergency_message)
                
        except Exception as e:
            print(f"Error sending gas alert for bin '{bin_id}': {e}")

    def _should_send_notification(self, bin_id: str, trash_level: float) -> bool:
        return bin_id not in self.last_known_trash_levels or \
               abs(self.last_known_trash_levels[bin_id] - trash_level) >= 1.0

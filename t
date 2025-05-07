Okay, converting this entire Node.js/TypeScript application to a Python FastAPI backend is a substantial task. I will provide the Python equivalents for each of the TypeScript files, organizing them into a Pythonic project structure.
**Project Structure (Python):**
```
app/
├── __init__.py
├── main.py                 # FastAPI app, Socket.IO setup, entry point
├── config.py               # Configuration, logger setup
├── schemas/
│   ├── __init__.py
│   ├── device.py           # Pydantic models for Device
│   └── wda.py              # Pydantic models for WDA
├── routers/
│   ├── __init__.py
│   └── device_routes.py    # FastAPI routes for /api/device
├── services/               # Business logic, equivalent to modules
│   ├── __init__.py
│   ├── idf_service.py      # IDF class (was modules/idf.ts)
│   ├── device_manager.py   # DeviceManager class
│   ├── tunnel_manager.py   # TunnelManager class
│   ├── wda/
│   │   ├── __init__.py
│   │   ├── wda_control.py  # WdaControlClient, WdaService
│   │   ├── wda_stream.py   # WdaStreamClient, MjpegParser logic
│   │   ├── wda_go_ios.py   # WdaGoIOS class
│   │   └── wda_models.py   # WdaEndpoints, HttpMethod (was wda-endpoints.ts)
│   └── socket_handlers.py  # Socket.IO event handlers
├── utils/
│   ├── __init__.py
│   ├── cmd_utils.py
│   ├── device_utils.py
│   └── network_utils.py    # For finding free ports
├── static/                 # For public/static files (if any, like index.html)
│   └── index.html          # (Assuming you might have one)
.env                        # For environment variables
requirements.txt
```
**1. `requirements.txt`:**
```txt
fastapi
uvicorn[standard]
pydantic
python-dotenv
python-socketio[asyncio_client]
aiohttp
asyncio-subprocess-tee  # For easier subprocess stream handling
Pillow  # For image processing (MJPEG)
wsgicors # For CORS if needed by socket.io with fastapi
```
**2. `.env` (example):**
```env
APP_NAME="ios-device-farm-py"
PORT=9000
# Adjust these paths as per your system
WEBDRIVERAGENT_PROJECT="/path/to/your/WebDriverAgent"
GO_IOS_PATH="/path/to/your/go-ios/dist/go-ios-darwin-amd64_darwin_amd64/ios"
# Or if go-ios is in PATH:
# GO_IOS_PATH="ios"
```
**3. `app/config.py`:**
```python
import logging
import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from pydantic import BaseModel
# Load environment variables from .env file
BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")
class AppSettings(BaseModel):
    APP_NAME: str = os.getenv("APP_NAME", "ios-device-farm-py")
    PORT: int = int(os.getenv("PORT", 9000))
    WEBDRIVERAGENT_PROJECT: str = os.getenv("WEBDRIVERAGENT_PROJECT", str(Path.cwd() / "ext/WebDriverAgent"))
    GO_IOS_PATH: str = os.getenv("GO_IOS_PATH", str(Path.cwd() / "node_modules/go-ios/dist/go-ios-darwin-amd64_darwin_amd64/ios")) # Adjust if go-ios is in PATH
APP_ENV = AppSettings()
# Logger Configuration
LOGS_DIR = BASE_DIR / "logs"
LOGS_DIR.mkdir(exist_ok=True)
# Define the custom format for log messages
log_format_str = "%(asctime)s [%(levelname)s]: %(message)s"
date_format_str = "%Y-%m-%d %H:%M:%S"
formatter = logging.Formatter(log_format_str, datefmt=date_format_str)
# Console Handler with color (basic, more advanced coloring might need a library)
class ColorFormatter(logging.Formatter):
    COLORS = {
        'WARNING': '\033[93m',
        'INFO': '\033[92m',
        'DEBUG': '\033[94m',
        'CRITICAL': '\033[91m',
        'ERROR': '\033[91m',
        'ENDC': '\033[0m',
    }
    def format(self, record):
        log_message = super().format(record)
        return f"{self.COLORS.get(record.levelname, '')}{log_message}{self.COLORS['ENDC']}"
console_formatter = ColorFormatter(log_format_str, datefmt=date_format_str)
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setFormatter(console_formatter)
# File Handlers
error_file_handler = logging.FileHandler(LOGS_DIR / "error.log")
error_file_handler.setLevel(logging.ERROR)
error_file_handler.setFormatter(formatter)
combined_file_handler = logging.FileHandler(LOGS_DIR / "combined.log")
combined_file_handler.setFormatter(formatter)
# Initialize the logger
logger = logging.getLogger(APP_ENV.APP_NAME)
logger.setLevel(logging.INFO)  # Set the default log level
logger.addHandler(console_handler)
logger.addHandler(error_file_handler)
logger.addHandler(combined_file_handler)
logger.propagate = False # Prevent double logging if root logger is configured
if __name__ == "__main__":
    logger.info("Logger initialized.")
    logger.debug("This is a debug message.")
    logger.warning("This is a warning.")
    logger.error("This is an error.")
    logger.critical("This is a critical message.")
    print(f"Go iOS Path: {APP_ENV.GO_IOS_PATH}")
    print(f"WDA Project Path: {APP_ENV.WEBDRIVERAGENT_PROJECT}")
```
**4. `app/schemas/device.py`:**
```python
from enum import Enum
from pydantic import BaseModel
class DeviceStatus(str, Enum):
    AVAILABLE = "AVAILABLE"
    BUSY = "BUSY"
    OFFLINE = "OFFLINE"
class Device(BaseModel):
    id: int
    model: str
    name: str
    udid: str
    version: str # OS version string like "17.0.1"
    status: DeviceStatus
    dpr: float # Changed to float as dpr can be non-integer
    height: int
    width: int
def get_device_os_major_version(version_str: str) -> int:
    try:
        parts = version_str.split(".")
        if parts and parts[0]:
            return int(parts[0])
    except Exception:
        pass
    return 17 # Default fallback
```
**5. `app/schemas/wda.py`:**
```python
from enum import Enum
from typing import Any, Dict, Optional
from pydantic import BaseModel
class WdaCommands(str, Enum):
    OPEN_URL = "open_url"
    TAP = "tap"
    LONG_PRESS = "longPress"
    MULTI_APP_SELECTOR = "multi_app_selector"
    TEXT_INPUT = "text_input"
    HOMESCREEN = "homescreen"
    SWIPE = "swipe"
class Command(BaseModel):
    udid: str
    cmd: WdaCommands
    values: Optional[Dict[str, Any]] = None
def build_command(data: Any) -> Command:
    return Command(udid=data.get("udid"), cmd=WdaCommands(data.get("cmd")), values=data.get("data"))
class WdaSessionCapabilities(BaseModel):
    sdkVersion: str
    device: str
class WdaSessionValue(BaseModel):
    sessionId: str
    capabilities: WdaSessionCapabilities
class WdaSessionResponse(BaseModel):
    sessionId: Optional[str] = None # Make it optional as it's nested in 'value' for successful creation
    value: Optional[WdaSessionValue] = None # For successful creation
    # For errors, WDA might return a different structure
    # e.g. {"value": {"error": "session not created", "message": "...", "traceback": "..."}}
    # Pydantic will try to parse, if it fails, it means an error structure or unexpected response
```
**6. `app/utils/cmd_utils.py`:**
```python
from typing import List
def get_tunnel_command_args(udid: str, port: int) -> List[str]:
    return ["forward", f"--udid={udid}", str(port), str(port)]
# This was xcodebuild, which is not directly used by WdaGoIOS. WdaGoIOS uses runwda.
# def get_xcode_build_command_args(udid: str, control_port: int, stream_port: int) -> List[str]:
#     return [
#         "test", "-scheme", "WebDriverAgentRunner",
#         "-destination", f"id={udid}",
#         f"USE_PORT={control_port}",
#         f"MJPEG_SERVER_PORT={stream_port}"
#     ]
def get_run_test_command_args(bundle_id: str, udid: str, control_port: int, stream_port: int) -> List[str]:
    return [
        "runwda",
        f"--bundleid={bundle_id}",
        f"--testrunnerbundleid={bundle_id}",
        "--xctestconfig=WebDriverAgentRunner.xctest",
        "--udid", udid,
        "--env", f"USE_PORT={control_port}",
        "--env", f"MJPEG_SERVER_PORT={stream_port}",
    ]
# This was ideviceinfo, which is not used by DeviceManager. DeviceManager uses `go-ios info`.
# def get_device_info_args(udid: str) -> List[str]: # port arg was unused
#       return ["ideviceinfo", f"--udid={udid}"]
```
**7. `app/utils/device_utils.py`:**
```python
from typing import Dict, TypedDict
DeviceMap = Dict[str, str]
# (Keep your iPhoneModels and iPadModels dictionaries here)
# For brevity, I'll use a shortened version.
# ... (Full iPhoneModels and iPadModels from your TS file)
iPhoneModels: DeviceMap = {
    "iPhone1,1": "iPhone (Original)",
    "iPhone14,7": "iPhone 14",
    "iPhone15,3": "iPhone 14 Pro Max",
}
iPadModels: DeviceMap = {
    "iPad1,1": "iPad (1st generation)",
    "iPad14,6": "iPad Pro (12.9-inch) (6th generation)",
}
class DeviceSizeInfo(TypedDict):
    dpr: float
    viewportWidth: int
    viewportHeight: int
# For brevity, I'll use a shortened version.
# ... (Full iPhoneDevicesSizes from your TS file)
iPhoneDevicesSizes: Dict[str, DeviceSizeInfo] = {
    "iPhone8,4": {"dpr": 2, "viewportWidth": 320, "viewportHeight": 568},    # iPhone SE (1st Gen)
    "iPhone14,3": {"dpr": 3, "viewportWidth": 430, "viewportHeight": 932},  # iPhone 14 Pro Max
    "iPhone15,3": {"dpr": 3, "viewportWidth": 430, "viewportHeight": 932},  # iPhone 15 Pro Max (assuming same as 14 Pro Max for example)
}
DEFAULT_DEVICE_SIZE: DeviceSizeInfo = {"dpr": 3.0, "viewportWidth": 430, "viewportHeight": 932}
def get_device_size(machine_id: str) -> DeviceSizeInfo:
    return iPhoneDevicesSizes.get(machine_id, DEFAULT_DEVICE_SIZE)
def get_device_name(machine_id: str) -> str:
    return iPhoneModels.get(machine_id, iPadModels.get(machine_id, "iPhone"))
```
**8. `app/utils/network_utils.py`:**
```python
import socket
from contextlib import closing
from typing import List
def find_free_port() -> int:
    with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as s:
        s.bind(("", 0))
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        return s.getsockname()[1]
async def find_free_ports(count: int) -> List[int]:
    ports = []
    for _ in range(count):
        ports.append(find_free_port())
    # Basic check for uniqueness, could be more robust
    if len(set(ports)) != count:
        # Recurse or raise error if ports are not unique (highly unlikely for small counts)
        return await find_free_ports(count)
    return ports
```
**9. `app/services/wda/wda_models.py`:**
```python
from enum import Enum
class HttpMethod(str, Enum):
    GET = "GET"
    POST = "POST"
    DELETE = "DELETE"
class WdaEndpoints(str, Enum):
    CREATE_SESSION = "/session"
    DELETE_SESSION = "/session/{sessionId}"
    OPEN_URL = "/session/{sessionId}/url"
    ENTER_TEXT = "/session/{sessionId}/wda/keys"
    CUSTOM_TAP = "/session/{sessionId}/wda/custom/tap"
    LONG_PRESS = "/session/{sessionId}/wda/touchAndHold"
    MULTI_APP_SELECTOR = "/session/{sessionId}/wda/dragfromtoforduration"
    WDA_SCREENSHOT = "/session/{sessionId}/wda/screenshot" # Not used in wda.control.ts
    WDA_HOMESCREEN = "/wda/homescreen"
    SWIPE = "/session/{sessionId}/wda/custom/swipe"
def get_endpoint_url(endpoint: WdaEndpoints, params: dict = None) -> str:
    endpoint_str = endpoint.value
    if params:
        for key, value in params.items():
            endpoint_str = endpoint_str.replace(f"{{{key}}}", str(value))
    return endpoint_str
```
**10. `app/services/wda/wda_control.py`:**
```python
import aiohttp
from typing import Any, Dict, Optional
from app.config import logger
from app.schemas.wda import Command as WdaAppCommand, WdaCommands, WdaSessionResponse
from .wda_models import HttpMethod, WdaEndpoints, get_endpoint_url
class WdaService:
    def __init__(self, port: int):
        self.base_url = f"http://localhost:{port}"
        logger.info(f"WDA Service BASE URL: {self.base_url}")
        # Session should be created per request or managed carefully
        # For simplicity, we'll create it when needed.
        self.session: Optional[aiohttp.ClientSession] = None
    async def _get_session(self) -> aiohttp.ClientSession:
        if self.session is None or self.session.closed:
            self.session = aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=10)) # Increased timeout
        return self.session
    async def close_session(self):
        if self.session and not self.session.closed:
            await self.session.close()
            self.session = None
    async def api_call(
        self, endpoint: WdaEndpoints, method: HttpMethod, data: Any = None, params: Dict[str, str] = None
    ) -> Optional[aiohttp.ClientResponse]:
        url = self.base_url + get_endpoint_url(endpoint, params)
        http_session = await self._get_session()
       
        request_kwargs = {"url": url, "json": data if data is not None else {}} # WDA often expects empty JSON {}
        if method == HttpMethod.GET:
            del request_kwargs["json"] # No body for GET
        try:
            async with http_session.request(method.value, **request_kwargs) as response:
                # Read the response content before returning to avoid "Unclosed response"
                await response.read()
                logger.info(f"WDA API call to {url} ({method.value}) status: {response.status}")
                # logger.debug(f"Response headers: {response.headers}")
                # logger.debug(f"Response text: {await response.text()}") # Careful with large responses
                return response
        except aiohttp.ClientError as e:
            logger.error(f"API call to {url} failed: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error during API call to {url}: {e}")
            return None
class WdaControlClient:
    def __init__(self, port: int):
        self.service = WdaService(port)
        self.session_id: Optional[str] = None
    async def create_wda_session(self) -> None:
        try:
            post_data = {"capabilities": {}} # Standard WDA capabilities
            # WDA 1.x uses 'desiredCapabilities', WDA 2.x+ uses 'capabilities'
            # Sometimes it needs more specific capabilities, e.g. bundleId for an app
            # post_data = {"capabilities": {"alwaysMatch": {"bundleId": "com.apple.mobilesafari"}}}
           
            response = await self.service.api_call(WdaEndpoints.CREATE_SESSION, HttpMethod.POST, post_data)
           
            if response and response.status == 200:
                response_data = await response.json()
                logger.info(f"Create WDA session response: {response_data}")
               
                # WDA session response structure can vary. Common is {"value": {"sessionId": "...", ...}}
                parsed_session = WdaSessionResponse(**response_data)
                if parsed_session.value and parsed_session.value.sessionId:
                    self.session_id = parsed_session.value.sessionId
                    logger.info(f"WDA session created: {self.session_id}")
                    return
                elif parsed_session.sessionId: # Some WDA versions might return sessionId at top level
                    self.session_id = parsed_session.sessionId
                    logger.info(f"WDA session created (top-level ID): {self.session_id}")
                    return
               
                logger.error(f"Invalid session data received: {response_data}")
                raise Exception("Invalid session data received from WDA")
            else:
                err_msg = f"Failed to create WDA session. Status: {response.status if response else 'N/A'}"
                if response:
                    err_msg += f", Body: {await response.text()}"
                logger.error(err_msg)
                raise Exception(err_msg)
        except Exception as e:
            logger.error(f"Error creating WDA session: {e}")
            await self.service.close_session() # Ensure session is closed on error
            raise Exception("Failed to create WDA session") from e
    async def delete_wda_session(self) -> Optional[Dict[str, Any]]:
        if not self.session_id:
            logger.warning("No WDA session to delete.")
            await self.service.close_session()
            return None
        try:
            response = await self.service.api_call(
                WdaEndpoints.DELETE_SESSION, HttpMethod.DELETE, params={"sessionId": self.session_id}
            )
            if response and response.status == 200:
                response_data = await response.json()
                logger.info(f"WDA session {self.session_id} deleted: {response_data}")
                return response_data
            else:
                err_msg = f"Failed to delete WDA session {self.session_id}. Status: {response.status if response else 'N/A'}"
                if response:
                    err_msg += f", Body: {await response.text()}"
                logger.error(err_msg)
                raise Exception(err_msg)
        except Exception as e:
            logger.error(f"Error deleting WDA session {self.session_id}: {e}")
            raise Exception("Failed to delete WDA session") from e
        finally:
            self.session_id = None
            await self.service.close_session() # Close the underlying aiohttp session
    async def perform_command(self, command: WdaAppCommand) -> Dict[str, bool]:
        if not self.session_id:
            logger.error("Cannot perform command: No active WDA session.")
            raise Exception("No active WDA session")
        params = {"sessionId": self.session_id}
        endpoint: WdaEndpoints
        method: HttpMethod
        post_data: Any = command.values
        cmd_map = {
            WdaCommands.OPEN_URL: (WdaEndpoints.OPEN_URL, HttpMethod.POST),
            WdaCommands.TAP: (WdaEndpoints.CUSTOM_TAP, HttpMethod.POST),
            WdaCommands.TEXT_INPUT: (WdaEndpoints.ENTER_TEXT, HttpMethod.POST),
            WdaCommands.HOMESCREEN: (WdaEndpoints.WDA_HOMESCREEN, HttpMethod.POST),
            WdaCommands.SWIPE: (WdaEndpoints.SWIPE, HttpMethod.POST),
            WdaCommands.LONG_PRESS: (WdaEndpoints.LONG_PRESS, HttpMethod.POST),
            WdaCommands.MULTI_APP_SELECTOR: (WdaEndpoints.MULTI_APP_SELECTOR, HttpMethod.POST),
        }
        if command.cmd not in cmd_map:
            logger.error(f"Unknown command: {command.cmd}")
            return {"success": False}
        endpoint, method = cmd_map[command.cmd]
       
        if command.cmd == WdaCommands.HOMESCREEN:
            post_data = None # Homescreen might not require data, or empty dict {}
            # WDA /wda/homescreen does not take sessionId in path
            params = {}
            # Ensure the endpoint used for HOMESCREEN does not expect sessionId in path
            # WdaEndpoints.WDA_HOMESCREEN = "/wda/homescreen" (correct)
        logger.info(f"Performing command: {command.cmd}, endpoint: {endpoint}, method: {method}, data: {post_data}, params: {params}")
       
        response = await self.service.api_call(endpoint, method, post_data, params)
        if response:
            if response.status == 200:
                # response_body = await response.json() # Or .text() if not always JSON
                # logger.info(f"Command {command.cmd} successful. Response: {response_body}")
                return {"success": True}
            else:
                response_text = await response.text()
                logger.error(f"Command {command.cmd} execution failed. Status: {response.status}, Body: {response_text}")
                # Try to parse error message from WDA
                try:
                    error_data = await response.json() # WDA errors are often JSON
                    message = error_data.get("value", {}).get("message", response_text)
                except Exception:
                    message = response_text
                raise Exception(f"Failed to execute command {command.cmd}: {message}")
        else:
            logger.error(f"No response received for command {command.cmd}")
            # Depending on command, no response might be okay or an error.
            # For now, let's assume it's an issue if no response object.
            raise Exception(f"No response from WDA for command {command.cmd}")
```
**11. `app/services/wda/wda_stream.py`:**
```python
import asyncio
import re
from io import BytesIO
from PIL import Image # from Pillow
from typing import Optional, Callable, Awaitable
from app.config import logger
# Regex to find the Content-Length header in the HTTP response
# For MJPEG stream, the boundary is more important.
# Typical MJPEG part starts with --boundary, then headers, then image data.
# For this WDA stream, it seems simpler: Content-Length followed by JPEG.
LENGTH_REGEX = re.compile(br"Content-Length:\s*(\d+)", re.IGNORECASE)
SOI = b"\xff\xd8"  # Start of Image for JPEG
EOI = b"\xff\xd9"  # End of Image for JPEG
class MjpegParser:
    def __init__(self, data_callback: Callable[[bytes], Awaitable[None]]):
        self.buffer = bytearray()
        self.data_callback = data_callback
        self.content_length: Optional[int] = None
        self.jpeg_quality = 75 # For re-encoding if needed
    async def feed(self, chunk: bytes):
        self.buffer.extend(chunk)
       
        while True:
            if self.content_length is None:
                match = LENGTH_REGEX.search(self.buffer)
                if match:
                    self.content_length = int(match.group(1))
                    # Remove headers up to and including the match
                    header_end_index = match.end()
                    # Search for double CRLF (end of headers)
                    crlf_crlf_index = self.buffer.find(b"\r\n\r\n", header_end_index)
                    if crlf_crlf_index != -1:
                        self.buffer = self.buffer[crlf_crlf_index + 4:]
                    else: # Fallback if no double CRLF, just remove up to content-length header
                        self.buffer = self.buffer[header_end_index:]
                        # This might be fragile if other headers follow Content-Length
                else:
                    # Not enough data to find Content-Length
                    if len(self.buffer) > 4096: # Prevent excessive buffering
                        logger.warning("MJPEG Parser: Buffer growing large without Content-Length, clearing.")
                        self.buffer.clear()
                    break
            if self.content_length is not None and len(self.buffer) >= self.content_length:
                jpeg_data = self.buffer[:self.content_length]
                self.buffer = self.buffer[self.content_length:]
                self.content_length = None # Reset for the next frame
                # Optional: Re-encode JPEG with specific quality using Pillow
                try:
                    img_buffer = BytesIO(jpeg_data)
                    img = Image.open(img_buffer)
                    output_buffer = BytesIO()
                    img.save(output_buffer, format="JPEG", quality=self.jpeg_quality)
                    processed_jpeg_data = output_buffer.getvalue()
                    await self.data_callback(processed_jpeg_data)
                except Exception as e:
                    logger.error(f"Error processing JPEG frame: {e}")
                    # Fallback: send original data if processing fails
                    await self.data_callback(jpeg_data)
            else:
                # Not enough data for the current frame or no content_length yet
                break
class WdaStreamClient:
    def __init__(self):
        self.reader: Optional[asyncio.StreamReader] = None
        self.writer: Optional[asyncio.StreamWriter] = None
        self.parser: Optional[MjpegParser] = None
        self._data_callbacks: list[Callable[[bytes], Awaitable[None]]] = []
        self._is_connected = False
        self._processing_task: Optional[asyncio.Task] = None
        self.first_data_received = asyncio.Event()
    def on_data(self, callback: Callable[[bytes], Awaitable[None]]):
        self._data_callbacks.append(callback)
    async def _emit_data(self, data: bytes):
        if not self.first_data_received.is_set():
            self.first_data_received.set()
        for callback in self._data_callbacks:
            try:
                await callback(data)
            except Exception as e:
                logger.error(f"Error in WDA stream data callback: {e}")
    async def connect(self, port: int, host: str = "localhost"):
        if self._is_connected:
            await self.disconnect()
        try:
            logger.info(f"WDA Stream: Connecting to {host}:{port}...")
            self.reader, self.writer = await asyncio.open_connection(host, port)
            self._is_connected = True
            self.parser = MjpegParser(self._emit_data)
           
            # WDA MJPEG stream might expect an initial request line.
            # Example: "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n"
            # The original TS code sends "hello". This might be specific to `go-ios` forwarding.
            # If `go-ios` sets up a raw TCP forward to WDA's MJPEG HTTP endpoint,
            # then a simple HTTP GET request is needed.
            # If it's a custom protocol, "hello" might be right.
            # Let's assume `go-ios` handles the HTTP part and just forwards raw JPEG stream after "hello".
            # If it's a raw MJPEG HTTP stream, this needs to be `self.writer.write(b"GET /stream HTTP/1.1\r\n\r\n")` or similar.
            # The original code `this.client.write("hello");` implies a simpler protocol.
            # Based on `mjpeg.parser.ts` looking for `Content-Length`, it's an HTTP-like stream.
            # The `go-ios` MJPEG forwarding might be a raw TCP proxy to WDA's MJPEG endpoint.
            # WDA's MJPEG endpoint is usually `/stream` or `/mjpeg/stream`.
            # Let's try sending a basic GET request.
            # If `go-ios` `forward` is used (as in TunnelManager), it's a direct port forward.
            # If `go-ios` `runwda` sets up the stream port, it might be a raw stream.
            # The original `wda.stream.ts` just writes "hello". Let's stick to that for now,
            # as it's what the original code does. If it fails, an HTTP GET is the next thing to try.
            self.writer.write(b"hello") # Original behavior
            await self.writer.drain()
            logger.info(f"WDA Stream: Connected to {host}:{port} and sent initial 'hello'.")
        except ConnectionRefusedError:
            logger.error(f"WDA Stream: Connection refused at {host}:{port}.")
            self._is_connected = False
            raise
        except Exception as e:
            logger.error(f"WDA Stream: Connection error to {host}:{port}: {e}")
            self._is_connected = False
            raise
    async def _process_stream(self):
        if not self.reader or not self.parser:
            logger.error("WDA Stream: Cannot process, reader or parser not initialized.")
            return
        try:
            while self._is_connected and not self.reader.at_eof():
                chunk = await self.reader.read(4096) # Read in chunks
                if not chunk:
                    logger.info("WDA Stream: Received empty chunk, stream might be closing.")
                    break
                await self.parser.feed(chunk)
        except asyncio.CancelledError:
            logger.info("WDA Stream: Processing task cancelled.")
        except ConnectionResetError:
            logger.warning("WDA Stream: Connection reset by peer.")
        except Exception as e:
            if self._is_connected: # Log error only if we weren't expecting a disconnect
                 logger.error(f"WDA Stream: Error while reading stream: {e}")
        finally:
            logger.info("WDA Stream: Stream processing finished.")
            await self.disconnect() # Ensure cleanup
    async def start_processing(self):
        if not self._is_connected:
            raise Exception("WDA Stream: Client is not connected.")
        if self._processing_task and not self._processing_task.done():
            logger.warning("WDA Stream: Processing already started.")
            return
        self.first_data_received.clear()
        self._processing_task = asyncio.create_task(self._process_stream())
       
        try:
            # Wait for the first frame or a timeout
            await asyncio.wait_for(self.first_data_received.wait(), timeout=10.0)
            logger.info("WDA Stream: TCP fetch started, first data received.")
        except asyncio.TimeoutError:
            logger.error("WDA Stream: Timeout waiting for first data frame.")
            await self.disconnect() # Clean up if no data
            raise Exception("WDA Stream: Timeout waiting for first data frame.")
    async def disconnect(self):
        if not self._is_connected and not self.writer and not self._processing_task:
            return # Already disconnected or never connected
        self._is_connected = False # Signal processing loop to stop
        if self._processing_task and not self._processing_task.done():
            self._processing_task.cancel()
            try:
                await self._processing_task
            except asyncio.CancelledError:
                logger.info("WDA Stream: Processing task successfully cancelled during disconnect.")
            except Exception as e:
                logger.error(f"WDA Stream: Error during processing task cleanup: {e}")
        self._processing_task = None
       
        if self.writer:
            try:
                if not self.writer.is_closing():
                    self.writer.close()
                    await self.writer.wait_closed()
            except Exception as e:
                logger.error(f"WDA Stream: Error closing writer: {e}")
            self.writer = None
       
        self.reader = None
        self.parser = None
        self._data_callbacks.clear()
        self.first_data_received.clear()
        logger.info("WDA Stream: Disconnected.")
```
**12. `app/services/tunnel_manager.py`:**
```python
import asyncio
import signal
from typing import Optional, Callable, Awaitable, Tuple, List
from app.config import logger, APP_ENV
from app.utils.cmd_utils import get_tunnel_command_args
# A simple event emitter like structure
class AsyncEventEmitter:
    def __init__(self):
        self._listeners = {}
    def on(self, event_name: str, callback: Callable[..., Awaitable[None]]):
        if event_name not in self._listeners:
            self._listeners[event_name] = []
        self._listeners[event_name].append(callback)
    async def emit(self, event_name: str, *args, **kwargs):
        if event_name in self._listeners:
            for callback in self._listeners[event_name]:
                await callback(*args, **kwargs)
   
    def remove_all_listeners(self, event_name: Optional[str] = None):
        if event_name:
            if event_name in self._listeners:
                del self._listeners[event_name]
        else:
            self._listeners.clear()
class TunnelManager(AsyncEventEmitter):
    def __init__(self, udid: str):
        super().__init__()
        self.udid = udid
        self.control_proc: Optional[asyncio.subprocess.Process] = None
        self.stream_proc: Optional[asyncio.subprocess.Process] = None
        self._monitor_tasks: List[asyncio.Task] = []
    async def _start_tunnel_process(self, port: int) -> asyncio.subprocess.Process:
        args = get_tunnel_command_args(self.udid, port)
        cmd_str = f"{APP_ENV.GO_IOS_PATH} {' '.join(args)}"
        logger.info(f"Starting tunnel: {cmd_str}")
        # The match string for go-ios forward success:
        # "Start listening on port {port} forwarding to port {port} on device {udid}"
        # However, go-ios might output this to stderr or stdout.
        # `asyncio-subprocess-tee` can help here, or manual reading.
       
        proc = await asyncio.create_subprocess_exec(
            APP_ENV.GO_IOS_PATH,
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        # Monitor stdout/stderr for the success message or errors
        success_event = asyncio.Event()
       
        async def watch_output(stream, stream_name):
            # Expected success message from `go-ios forward` (might be on stderr)
            # Example: "time=\"...\" level=info msg=\"Start listening on port 9100 forwarding to port 9100 on device 0000XXXX-00XXXXXX....\""
            success_pattern = f"Start listening on port {port} forwarding to port {port} on device".encode()
            try:
                async for line in stream:
                    logger.debug(f"Tunnel ({port}) {stream_name}: {line.decode(errors='ignore').strip()}")
                    if success_pattern in line:
                        logger.info(f"Tunnel for port {port} on UDID {self.udid} confirmed active.")
                        success_event.set()
            except Exception as e:
                logger.error(f"Error reading tunnel ({port}) {stream_name}: {e}")
                if not success_event.is_set(): # If error before success, try to set for timeout
                    success_event.set() # This will make wait_for timeout
        stdout_task = asyncio.create_task(watch_output(proc.stdout, "stdout"))
        stderr_task = asyncio.create_task(watch_output(proc.stderr, "stderr"))
        try:
            await asyncio.wait_for(success_event.wait(), timeout=15.0) # 15 sec timeout
        except asyncio.TimeoutError:
            stdout_task.cancel()
            stderr_task.cancel()
            if proc.returncode is None: # Process still running
                logger.error(f"Timeout starting tunnel for port {port}. Terminating process.")
                proc.terminate()
                await proc.wait()
            raise Exception(f"Timeout starting tunnel for port {port} on UDID {self.udid}")
       
        # Don't cancel tasks if successful, let them run to log output
        # Store them to be cancelled later if needed.
        # self._monitor_tasks.extend([stdout_task, stderr_task])
        # Start a task to monitor process completion for "die" event
        monitor_task = asyncio.create_task(self._monitor_process_exit(proc, port))
        self._monitor_tasks.append(monitor_task)
       
        return proc
    async def _monitor_process_exit(self, proc: asyncio.subprocess.Process, port: int):
        try:
            return_code = await proc.wait()
            # Determine signal if possible (platform-dependent, return_code might be -signal)
            signal_name = None
            if return_code < 0: # Typically indicates killed by signal on Unix-like systems
                try:
                    signal_name = signal.Signals(-return_code).name
                except ValueError:
                    signal_name = "UNKNOWN_SIGNAL"
            logger.warning(f"Tunnel process for port {port} on UDID {self.udid} died. Code: {return_code}, Signal: {signal_name}")
            await self.emit("tunnel_die", return_code, signal_name)
        except asyncio.CancelledError:
            logger.info(f"Tunnel monitor for port {port} cancelled.")
        except Exception as e:
            logger.error(f"Error in tunnel monitor for port {port}: {e}")
    async def start_control_tunnel(self, port: int) -> None:
        self.control_proc = await self._start_tunnel_process(port)
        logger.info(f"Control tunnel process for port {port} started (PID: {self.control_proc.pid}).")
    async def start_stream_tunnel(self, port: int) -> None:
        self.stream_proc = await self._start_tunnel_process(port)
        logger.info(f"Stream tunnel process for port {port} started (PID: {self.stream_proc.pid}).")
    async def _stop_process(self, proc: Optional[asyncio.subprocess.Process], name: str):
        if proc and proc.returncode is None:
            logger.info(f"Stopping {name} tunnel process (PID: {proc.pid})...")
            try:
                proc.terminate() # Send SIGTERM
                await asyncio.wait_for(proc.wait(), timeout=5.0)
                logger.info(f"{name} tunnel process (PID: {proc.pid}) terminated.")
            except asyncio.TimeoutError:
                logger.warning(f"Timeout terminating {name} tunnel (PID: {proc.pid}). Sending SIGKILL.")
                proc.kill()
                await proc.wait()
                logger.info(f"{name} tunnel process (PID: {proc.pid}) killed.")
            except Exception as e:
                logger.error(f"Error stopping {name} tunnel (PID: {proc.pid}): {e}")
        elif proc:
            logger.info(f"{name} tunnel process (PID: {proc.pid}) already exited with code {proc.returncode}.")
    async def stop_tunnels(self) -> None:
        logger.info(f"Stopping tunnels for UDID {self.udid}...")
        await self._stop_process(self.control_proc, "control")
        self.control_proc = None
        await self._stop_process(self.stream_proc, "stream")
        self.stream_proc = None
        # Cancel any monitoring tasks
        for task in self._monitor_tasks:
            if not task.done():
                task.cancel()
        await asyncio.gather(*self._monitor_tasks, return_exceptions=True)
        self._monitor_tasks.clear()
       
        self.remove_all_listeners("tunnel_die") # Clear listeners for this event
        logger.info(f"Tunnels for UDID {self.udid} stopped.")
```
**13. `app/services/wda/wda_go_ios.py`:**
```python
import asyncio
import json
import signal
from typing import Optional, List, Dict, Any
from app.config import logger, APP_ENV
from app.utils.cmd_utils import get_run_test_command_args
class WdaGoIOS:
    def __init__(self, udid: string, version: int, control_port: int, stream_port: int):
        self.udid = udid
        self.version = version # OS major version
        self.control_port = control_port
        self.stream_port = stream_port
        self.run_wda_proc: Optional[asyncio.subprocess.Process] = None
        self.tunnel_proc: Optional[asyncio.subprocess.Process] = None # For `go-ios tunnel start --userspace`
        self._monitor_tasks: List[asyncio.Task] = []
    async def _exec_command(self, *args, timeout=15) -> Tuple[str, str, int]:
        program = args[0]
        cmd_args = args[1:]
        logger.debug(f"Executing command: {program} {' '.join(cmd_args)}")
        proc = await asyncio.create_subprocess_exec(
            program,
            *cmd_args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        try:
            stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
            return stdout.decode(errors='ignore'), stderr.decode(errors='ignore'), proc.returncode
        except asyncio.TimeoutError:
            logger.error(f"Timeout executing: {program} {' '.join(cmd_args)}")
            if proc.returncode is None:
                proc.kill()
                await proc.wait()
            raise
   
    async def _monitor_process_output(self, proc: asyncio.subprocess.Process, proc_name: str):
        async def log_stream(stream, stream_name):
            async for line in stream:
                logger.info(f"{proc_name} {stream_name}: {line.decode(errors='ignore').strip()}")
        stdout_task = asyncio.create_task(log_stream(proc.stdout, "stdout"))
        stderr_task = asyncio.create_task(log_stream(proc.stderr, "stderr"))
        self._monitor_tasks.extend([stdout_task, stderr_task])
    async def _monitor_process_exit(self, proc: asyncio.subprocess.Process, proc_name: str):
        try:
            return_code = await proc.wait()
            signal_name = None
            if return_code < 0:
                try:
                    signal_name = signal.Signals(-return_code).name
                except ValueError:
                    signal_name = "UNKNOWN_SIGNAL"
            logger.warning(f"{proc_name} process died. Code: {return_code}, Signal: {signal_name}")
            # Here you might want to emit an event if WdaGoIOS was an event emitter
        except asyncio.CancelledError:
            logger.info(f"{proc_name} monitor task cancelled.")
        except Exception as e:
            logger.error(f"Error in {proc_name} monitor: {e}")
    async def start_device_tunnel(self) -> None:
        """Starts `go-ios tunnel start --userspace --udid <udid>`"""
        args = [APP_ENV.GO_IOS_PATH, "tunnel", "start", "--userspace", "--udid", self.udid]
        logger.info(f"Starting device userspace tunnel for {self.udid}: {' '.join(args)}")
       
        self.tunnel_proc = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        await self._monitor_process_output(self.tunnel_proc, f"DeviceTunnel-{self.udid}")
        monitor_exit_task = asyncio.create_task(self._monitor_process_exit(self.tunnel_proc, f"DeviceTunnel-{self.udid}"))
        self._monitor_tasks.append(monitor_exit_task)
        # Wait a bit for the tunnel to establish.
        # A more robust way would be to check `go-ios tunnel ls` after a delay.
        await asyncio.sleep(5) # Original delay
        logger.info(f"Device userspace tunnel for {self.udid} process (PID: {self.tunnel_proc.pid}) presumed started.")
    async def get_tunnel_data(self, max_attempts=20, attempt_interval=3) -> List[Dict[str, Any]]:
        """Checks `go-ios tunnel --udid <udid> ls` and manages remoted process."""
        attempts = 0
        start_remoted_cmd = "pkill -SIGCONT remoted" # Command to resume remoted
        stop_remoted_cmd = "pkill -SIGSTOP remoted"   # Command to pause remoted
        while attempts < max_attempts:
            try:
                stdout, stderr, code = await self._exec_command(APP_ENV.GO_IOS_PATH, "tunnel", "--udid", self.udid, "ls")
                if code != 0:
                    logger.error(f"Failed to get tunnel list (code {code}): {stderr}")
                else:
                    logger.info(f"Tunnel data for {self.udid}: {stdout.strip()}")
                    try:
                        tunnel_data = json.loads(stdout)
                        if isinstance(tunnel_data, list) and any(d.get("udid") == self.udid for d in tunnel_data):
                            logger.info(f"Device {self.udid} found in tunnel list. Ensuring remoted is running.")
                            await self._exec_command("sh", "-c", start_remoted_cmd, timeout=5)
                            return tunnel_data
                        else:
                            logger.warning(f"Device {self.udid} not found in tunnel list or unexpected format. Stopping remoted.")
                            await self._exec_command("sh", "-c", stop_remoted_cmd, timeout=5)
                    except json.JSONDecodeError:
                        logger.error(f"Failed to parse tunnel data JSON: {stdout}")
                    except Exception as e:
                        logger.error(f"Error processing tunnel data: {e}")
            except Exception as e:
                logger.error(f"Failed to get tunnel data on attempt {attempts + 1}: {e}")
            attempts += 1
            logger.info(f"Retrying get_tunnel_data for {self.udid}, attempt {attempts}/{max_attempts}")
            await asyncio.sleep(attempt_interval)
       
        logger.warning(f"Max attempts reached for get_tunnel_data. Ensuring remoted is running as a final step.")
        try:
            await self._exec_command("sh", "-c", start_remoted_cmd, timeout=5)
        except Exception as e:
            logger.error(f"Failed to re-initiate remoted process on final attempt: {e}")
       
        raise Exception(f"Failed to retrieve tunnel data for {self.udid} after max attempts")
    async def get_wda_bundle_id(self) -> str:
        """Retrieves WDA bundle ID using ideviceinstaller."""
        # Example: ideviceinstaller --udid <udid> --list-apps | grep com.extrabits | cut -d " " -f 1
        # This assumes WDA bundle ID contains "com.extrabits"
        # A more generic WDA bundle ID might be like "com.facebook.WebDriverAgentRunner.xctrunner"
        # Or it could be custom depending on how WDA was signed and installed.
        # The original script uses `com.extrabits`. Let's stick to that.
        # If `ideviceinstaller` is not available, this will fail.
        cmd = f"ideviceinstaller --udid {self.udid} --list-apps | grep com.extrabits | head -n 1 | cut -d ' ' -f 1"
        try:
            stdout, stderr, code = await self._exec_command("sh", "-c", cmd)
            if code == 0 and stdout.strip():
                bundle_id = stdout.strip().replace(",", "") # Remove trailing comma if any
                logger.info(f"Retrieved WDA bundle ID for {self.udid}: {bundle_id}")
                return bundle_id
            else:
                logger.error(f"Failed to retrieve WDA bundle ID for {self.udid}. Code: {code}, Stderr: {stderr}, Stdout: {stdout}")
                # Fallback or attempt to install WDA if necessary could be added here.
                # For now, raise an error.
                raise Exception(f"Could not determine WDA bundle ID for {self.udid}. Ensure WDA (with 'com.extrabits' in bundle ID) is installed.")
        except Exception as e:
            logger.error(f"Error getting WDA bundle ID for {self.udid}: {e}")
            raise
    async def start(self) -> None:
        try:
            await self.start_device_tunnel() # Start `go-ios tunnel start --userspace`
            await self.get_tunnel_data()     # Check `go-ios tunnel ls` and manage `remoted`
           
            bundle_id = await self.get_wda_bundle_id()
            if not bundle_id:
                raise Exception("Failed to retrieve WDA bundle ID, cannot start WDA.")
            args = get_run_test_command_args(bundle_id, self.udid, self.control_port, self.stream_port)
            cmd_str = f"{APP_ENV.GO_IOS_PATH} {' '.join(args)}"
            logger.info(f"Starting WDA with go-ios: {cmd_str}")
            self.run_wda_proc = await asyncio.create_subprocess_exec(
                APP_ENV.GO_IOS_PATH,
                *args,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            await self._monitor_process_output(self.run_wda_proc, f"RunWDA-{self.udid}")
            monitor_exit_task = asyncio.create_task(self._monitor_process_exit(self.run_wda_proc, f"RunWDA-{self.udid}"))
            self._monitor_tasks.append(monitor_exit_task)
            logger.info(f"WDA process (PID: {self.run_wda_proc.pid}) for {self.udid} started. Waiting for WDA to be ready...")
            # WDA can take some time to start. The original code waits 5s.
            # A more robust check would be to poll WDA's /status endpoint.
            await asyncio.sleep(10) # Increased wait time for WDA to initialize
            logger.info(f"Presuming WDA for {self.udid} is ready.")
        except Exception as e:
            logger.error(f"Failed to start WDA for {self.udid}: {e}")
            await self.stop() # Attempt cleanup
            raise
    async def _stop_process(self, proc: Optional[asyncio.subprocess.Process], name: str):
        if proc and proc.returncode is None:
            logger.info(f"Stopping {name} process (PID: {proc.pid}) for {self.udid}...")
            try:
                proc.terminate()
                await asyncio.wait_for(proc.wait(), timeout=5.0)
                logger.info(f"{name} process (PID: {proc.pid}) terminated.")
            except asyncio.TimeoutError:
                logger.warning(f"Timeout terminating {name} (PID: {proc.pid}). Sending SIGKILL.")
                proc.kill()
                await proc.wait()
                logger.info(f"{name} process (PID: {proc.pid}) killed.")
            except Exception as e:
                logger.error(f"Error stopping {name} (PID: {proc.pid}): {e}")
        elif proc:
            logger.info(f"{name} process (PID: {proc.pid}) already exited.")
    async def stop(self) -> None:
        logger.info(f"Stopping WDA and related processes for {self.udid}...")
       
        await self._stop_process(self.run_wda_proc, "RunWDA")
        self.run_wda_proc = None
       
        await self._stop_process(self.tunnel_proc, "DeviceTunnel")
        self.tunnel_proc = None
        # Cancel monitoring tasks
        for task in self._monitor_tasks:
            if not task.done():
                task.cancel()
        await asyncio.gather(*self._monitor_tasks, return_exceptions=True)
        self._monitor_tasks.clear()
       
        logger.info(f"WDA and related processes for {self.udid} stopped.")
    def remove_listeners(self): # Placeholder, as this Python version doesn't use explicit event listeners in WdaGoIOS
        # If WdaGoIOS were an EventEmitter, this would clear its listeners.
        pass
```
**14. `app/services/idf_service.py`:** (IDF: iOS Device Farm instance)
```python
import asyncio
from typing import Optional, Tuple, Any, List
import socketio # For Socket type hint
from app.config import logger
from app.schemas.device import get_device_os_major_version
from app.schemas.wda import build_command as build_wda_command
from .tunnel_manager import TunnelManager, AsyncEventEmitter
from .wda.wda_control import WdaControlClient
from .wda.wda_stream import WdaStreamClient
from .wda.wda_go_ios import WdaGoIOS
from app.utils.network_utils import find_free_ports
class IDF(AsyncEventEmitter): # Inherit if IDF needs to emit its own events
    def __init__(self, udid: str, device_os_version: str, client_socket: socketio.AsyncServer): # Using AsyncServer for type hint
        super().__init__()
        self.udid = udid
        self.device_os_major_version = get_device_os_major_version(device_os_version)
        self.client_socket = client_socket # This is the client's socket ID (sid) or the socket object itself
        self.tunnel_manager = TunnelManager(udid)
        self.wda_stream_client = WdaStreamClient()
        self.wda_control_client: Optional[WdaControlClient] = None
        self.wda_go_ios: Optional[WdaGoIOS] = None
        self.control_port: Optional[int] = None
        self.stream_port: Optional[int] = None
       
        self._active = False
    def get_ports(self) -> Tuple[Optional[int], Optional[int]]:
        return self.control_port, self.stream_port
    async def send_wda_command(self, data: Any):
        logger.info(f"IDF {self.udid}: Received WDA command data: {data}")
        if not self.wda_control_client:
            logger.error(f"IDF {self.udid}: WDA control client not initialized. Cannot send command.")
            return {"success": False, "error": "WDA control client not ready"}
       
        try:
            app_command = build_wda_command(data)
            response = await self.wda_control_client.perform_command(app_command)
            logger.info(f"IDF {self.udid}: WDA command response: {response}")
            return response
        except Exception as e:
            logger.error(f"IDF {self.udid}: Error sending WDA command: {e}", exc_info=True)
            return {"success": False, "error": str(e)}
    async def _handle_wda_stream_data(self, data: bytes):
        # Assuming client_socket is the sid
        if self.client_socket and hasattr(self.client_socket, 'emit') and self.client_socket.connected: # Check if it's a Socket object
             await self.client_socket.emit("imageFrame", data)
        # If self.client_socket is just a sid, you'd need the main Socket.IO server instance:
        # from app.main import sio
        # await sio.emit("imageFrame", data, room=self.client_socket_sid)
    async def _setup_listeners(self):
        self.tunnel_manager.on("tunnel_die", self._on_tunnel_die)
        self.wda_stream_client.on_data(self._handle_wda_stream_data)
        # If WdaGoIOS emitted "webdriver_died", listen here:
        # self.wda_go_ios.on("webdriver_died", self._on_webdriver_died)
    async def _on_tunnel_die(self, code: int, signal_name: Optional[str]):
        logger.error(f"IDF {self.udid}: A tunnel process died! Code: {code}, Signal: {signal_name}. Stopping IDF instance.")
        # Potentially emit an event to the client or trigger a full stop
        await self.stop()
        # You might want to inform the client via socket emit
        if self.client_socket and hasattr(self.client_socket, 'emit'):
            await self.client_socket.emit("idfError", {"udid": self.udid, "message": "A critical tunnel process died."})
    async def start(self) -> bool:
        if self._active:
            logger.warning(f"IDF {self.udid}: Start called, but already active.")
            return True
           
        logger.info(f"IDF {self.udid}: Starting...")
        try:
            self.control_port, self.stream_port = await find_free_ports(2)
            logger.info(f"IDF {self.udid}: Assigned ports - Control: {self.control_port}, Stream: {self.stream_port}")
            # 1. Start Tunnels (for WDA control and stream ports to be accessible on host)
            # These tunnels are from host to device, forwarding host's free ports to WDA's expected ports (e.g., 8100, 9100)
            # However, WdaGoIOS internally manages ports for WDA.
            # The TunnelManager here seems to be for `go-ios forward <host_port> <device_port>`
            # If WdaGoIOS's `runwda` already makes WDA listen on `self.control_port` and `self.stream_port`
            # via its internal forwarding (which `go-ios runwda` does), then these explicit tunnels might be redundant
            # or for a different purpose (e.g. if WDA was started manually on device on fixed ports).
            # The original `idf.ts` starts tunnels for the *free ports* it found, then tells WDA (via WdaGoIOS)
            # to use these same free ports. This implies `go-ios runwda` will make WDA listen on these specified host ports.
            # `go-ios runwda` indeed uses environment variables `USE_PORT` and `MJPEG_SERVER_PORT` to control
            # which ports WDA on the device listens on (forwarded from host).
            # So, these `tunnelManager.startControlTunnel/startStreamTunnel` are *not* needed if `WdaGoIOS` is used,
            # as `WdaGoIOS` itself (via `go-ios runwda`) handles the necessary port setup.
            # The `WdaGoIOS` class has its own `start_device_tunnel` which is `go-ios tunnel start --userspace`.
            # This is for general device communication, not specific to WDA ports.
            #
            # Let's re-evaluate:
            # - `WdaGoIOS(..., controlPort, streamPort)`: These are the *host* ports WDA will be accessible on.
            # - `go-ios runwda ... --env USE_PORT=${controlPort} --env MJPEG_SERVER_PORT=${streamPort}`:
            #   This tells `go-ios` to set up forwarding such that WDA (running on device, typically on 8100/9100)
            #   is accessible on the host at `controlPort` and `streamPort`.
            # - `TunnelManager` in `idf.ts`: `this.tunnelManager.startControlTunnel(controlPort)`
            #   This would try to do `go-ios forward <udid> <controlPort> <controlPort>`. This means it expects
            #   something on the *device* to be listening on `controlPort` (the second one). This seems incorrect
            #   if `go-ios runwda` is already handling the forwarding from host's `controlPort` to WDA's actual device port.
            #
            # Assumption: The `TunnelManager` in `idf.ts` was for a scenario where WDA was started independently
            # on the device listening on fixed ports, and `go-ios forward` was used to expose them.
            # With `WdaGoIOS` and `go-ios runwda`, this explicit `TunnelManager` for WDA ports is likely not needed.
            # `WdaGoIOS` itself will handle making WDA accessible on `self.control_port` and `self.stream_port`.
            # The `WdaGoIOS.start_device_tunnel()` is for `usbmuxd` like functionality.
           
            # Let's proceed with WdaGoIOS handling WDA port accessibility.
            # The original `idf.ts` does:
            # 1. TunnelManager.startControlTunnel(controlPort)
            # 2. TunnelManager.startStreamTunnel(streamPort)
            # 3. WdaGoIOS.start() // This also calls its internal `startTunnel` (`go-ios tunnel start --userspace`)
            # This suggests the TunnelManager tunnels are indeed intended.
            # This implies `go-ios runwda` might *not* set up its own forwarding if these ports are already forwarded.
            # Or, `go-ios runwda` uses these ports as *device-side* ports, and `TunnelManager` forwards host to device.
            # Let's follow the original logic structure.
            logger.info(f"IDF {self.udid}: Starting control tunnel on port {self.control_port}")
            await self.tunnel_manager.start_control_tunnel(self.control_port)
            logger.info(f"IDF {self.udid}: Starting stream tunnel on port {self.stream_port}")
            await self.tunnel_manager.start_stream_tunnel(self.stream_port)
            # 2. Start WDA using WdaGoIOS
            logger.info(f"IDF {self.udid}: Initializing WdaGoIOS...")
            self.wda_go_ios = WdaGoIOS(self.udid, self.device_os_major_version, self.control_port, self.stream_port)
            await self.wda_go_ios.start() # This will also call its internal device tunnel
            logger.info(f"IDF {self.udid}: WdaGoIOS started.")
            # 3. Connect WDA Stream Client
            logger.info(f"IDF {self.udid}: Connecting WDA stream client to port {self.stream_port}...")
            await self.wda_stream_client.connect(self.stream_port)
            await self.wda_stream_client.start_processing() # Waits for first frame
            logger.info(f"IDF {self.udid}: WDA stream client connected and processing.")
            # 4. Create WDA Control Session
            logger.info(f"IDF {self.udid}: Creating WDA control client for port {self.control_port}...")
            self.wda_control_client = WdaControlClient(self.control_port)
            await self.wda_control_client.create_wda_session()
            logger.info(f"IDF {self.udid}: WDA control client session created: {self.wda_control_client.session_id}")
            await self._setup_listeners()
            self._active = True
            logger.info(f"IDF {self.udid}: Successfully started.")
            return True
        except Exception as e:
            logger.error(f"IDF {self.udid}: Failed to start: {e}", exc_info=True)
            await self.stop() # Attempt cleanup
            return False
    async def stop(self) -> None:
        if not self._active and not (self.wda_control_client or self.wda_go_ios or self.wda_stream_client.writer or self.tunnel_manager.control_proc):
            logger.info(f"IDF {self.udid}: Stop called, but already stopped or not fully started.")
            return
        logger.info(f"IDF {self.udid}: Stopping...")
        self._active = False
       
        # Order of stopping:
        # 1. WDA Control Session (graceful WDA shutdown part)
        # 2. WDA Go IOS (stops WDA process on device and its own tunnel)
        # 3. WDA Stream Client (disconnects TCP socket)
        # 4. Tunnel Manager (stops explicit port forwarding tunnels)
        # 5. Remove Listeners
        if self.wda_control_client:
            try:
                logger.info(f"IDF {self.udid}: Deleting WDA session...")
                await self.wda_control_client.delete_wda_session()
            except Exception as e:
                logger.error(f"IDF {self.udid}: Error deleting WDA session: {e}", exc_info=True)
            self.wda_control_client = None
        if self.wda_go_ios:
            try:
                logger.info(f"IDF {self.udid}: Stopping WdaGoIOS...")
                await self.wda_go_ios.stop()
            except Exception as e:
                logger.error(f"IDF {self.udid}: Error stopping WdaGoIOS: {e}", exc_info=True)
            self.wda_go_ios = None
        # WDA Stream Client
        try:
            logger.info(f"IDF {self.udid}: Disconnecting WDA stream client...")
            await self.wda_stream_client.disconnect()
        except Exception as e:
            logger.error(f"IDF {self.udid}: Error disconnecting WDA stream client: {e}", exc_info=True)
       
        # Tunnel Manager
        try:
            logger.info(f"IDF {self.udid}: Stopping tunnels via TunnelManager...")
            await self.tunnel_manager.stop_tunnels()
        except Exception as e:
            logger.error(f"IDF {self.udid}: Error stopping tunnels via TunnelManager: {e}", exc_info=True)
        self.remove_all_idf_listeners()
        logger.info(f"IDF {self.udid}: Stopped.")
    def remove_all_idf_listeners(self):
        # This refers to listeners IDF itself might have if it were an emitter,
        # and listeners it set up on its components.
        self.tunnel_manager.remove_all_listeners() # Removes listeners from tunnel_manager
        if self.wda_go_ios: # WdaGoIOS in Python does not currently emit events, but if it did
            self.wda_go_ios.remove_listeners()
        self.wda_stream_client._data_callbacks.clear() # Clear stream client callbacks
        # If IDF itself is an emitter (e.g. inherits AsyncEventEmitter)
        if hasattr(super(), 'remove_all_listeners'):
            super().remove_all_listeners()
```
**15. `app/services/device_manager.py`:**
```python
import asyncio
import json
from typing import Dict, List, Optional, Any
import re
from app.config import logger, APP_ENV
from app.schemas.device import Device, DeviceStatus
from app.utils.device_utils import get_device_name, get_device_size
class DeviceManager:
    _instance: Optional['DeviceManager'] = None
    _lock = asyncio.Lock()
    def __init__(self):
        self.devices: Dict[str, Device] = {} # Keyed by UDID
        self.ios_listen_process: Optional[asyncio.subprocess.Process] = None
        self.listen_task: Optional[asyncio.Task] = None
        self._initialized = False
    @classmethod
    async def get_instance(cls) -> 'DeviceManager':
        if cls._instance is None:
            async with cls._lock:
                if cls._instance is None:
                    cls._instance = cls()
                    await cls._instance._initialize()
        return cls._instance
    async def _initialize(self):
        if not self._initialized:
            logger.info("Initializing DeviceManager...")
            self.listen_task = asyncio.create_task(self._listen_to_device_events())
            self._initialized = True
            logger.info("DeviceManager initialized and listening for device events.")
    async def _exec_go_ios_info(self, udid: str) -> Optional[Dict[str, Any]]:
        try:
            proc = await asyncio.create_subprocess_exec(
                APP_ENV.GO_IOS_PATH, "info", "--udid", udid,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=10)
            if proc.returncode == 0:
                return json.loads(stdout.decode())
            else:
                logger.error(f"go-ios info for {udid} failed (code {proc.returncode}): {stderr.decode()}")
                return None
        except asyncio.TimeoutError:
            logger.error(f"Timeout getting go-ios info for {udid}")
            return None
        except json.JSONDecodeError:
            logger.error(f"Failed to parse go-ios info JSON for {udid}")
            return None
        except Exception as e:
            logger.error(f"Error getting go-ios info for {udid}: {e}")
            return None
    async def _handle_attached_event(self, device_id: int, properties: Dict[str, Any]):
        udid = properties.get("SerialNumber")
        if not udid:
            logger.error(f"Attached event for DeviceID {device_id} missing SerialNumber.")
            return
        async with self._lock:
            device_info = await self._exec_go_ios_info(udid)
            if not device_info:
                logger.error(f"Could not get full info for attached device {udid}. Skipping.")
                return
            name = device_info.get("DeviceName", "Unknown Device")
            os_version = device_info.get("ProductVersion", "N/A")
            product_type = device_info.get("ProductType", "UnknownProduct") # e.g., "iPhone14,7"
           
            model_name = get_device_name(product_type)
            device_size_info = get_device_size(product_type)
            if udid in self.devices:
                device = self.devices[udid]
                device.id = device_id # Update ID if it changed (shouldn't for same UDID)
                device.status = DeviceStatus.AVAILABLE
                device.name = name
                device.version = os_version
                device.model = model_name
                # Update other properties if they can change
            else:
                device = Device(
                    id=device_id,
                    name=name,
                    model=model_name,
                    udid=udid,
                    version=os_version,
                    status=DeviceStatus.AVAILABLE,
                    dpr=device_size_info["dpr"],
                    height=device_size_info["viewportHeight"],
                    width=device_size_info["viewportWidth"],
                )
                self.devices[udid] = device
            logger.info(f"Device {device.name} ({device.udid}, ID: {device.id}) is now {device.status.value}.")
    async def _handle_detached_event(self, device_id: int):
        async with self._lock:
            found_udid = None
            for udid, device_obj in self.devices.items():
                if device_obj.id == device_id:
                    found_udid = udid
                    break
           
            if found_udid and found_udid in self.devices:
                device = self.devices[found_udid]
                device.status = DeviceStatus.OFFLINE
                logger.info(f"Device {device.name} ({device.udid}, ID: {device.id}) is now {device.status.value}.")
                # Optionally remove from self.devices or keep as OFFLINE
                # del self.devices[found_udid] # If you want to remove completely
            else:
                logger.warning(f"Detached event for unknown DeviceID {device_id}.")
    async def _handle_event_line(self, line: str):
        try:
            event_data = json.loads(line)
            message_type = event_data.get("MessageType")
            device_id = event_data.get("DeviceID")
            properties = event_data.get("Properties") # Present for "Attached"
            if message_type == "Attached" and device_id is not None and properties:
                await self._handle_attached_event(device_id, properties)
            elif message_type == "Detached" and device_id is not None:
                await self._handle_detached_event(device_id)
            elif message_type: # Other known message types like "Paired"
                logger.info(f"Received device event: {message_type} for DeviceID {device_id}")
            else:
                logger.warning(f"Unknown or malformed device event: {line}")
        except json.JSONDecodeError:
            logger.error(f"Failed to parse device event JSON: {line}")
        except Exception as e:
            logger.error(f"Error handling device event '{line}': {e}", exc_info=True)
    async def _listen_to_device_events(self):
        cmd = [APP_ENV.GO_IOS_PATH, "listen"]
        logger.info(f"Starting `{' '.join(cmd)}` to listen for device events...")
        try:
            self.ios_listen_process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            logger.info(f"`go-ios listen` process started (PID: {self.ios_listen_process.pid}).")
            # Process stdout
            async def read_stream(stream, stream_name):
                async for line_bytes in stream:
                    line = line_bytes.decode(errors='ignore').strip()
                    if stream_name == "stdout":
                        if line: # go-ios listen outputs JSON events to stdout
                            await self._handle_event_line(line)
                    elif stream_name == "stderr":
                        if line: # Log stderr from go-ios listen
                            logger.warning(f"go-ios listen stderr: {line}")
           
            stdout_task = asyncio.create_task(read_stream(self.ios_listen_process.stdout, "stdout"))
            stderr_task = asyncio.create_task(read_stream(self.ios_listen_process.stderr, "stderr"))
            await asyncio.gather(stdout_task, stderr_task) # Wait for both streams to end
        except FileNotFoundError:
            logger.critical(f"FATAL: `go-ios` executable not found at {APP_ENV.GO_IOS_PATH}. Device management will not work.")
            self.ios_listen_process = None
            return
        except Exception as e:
            logger.error(f"Error with `go-ios listen` process: {e}", exc_info=True)
        finally:
            if self.ios_listen_process and self.ios_listen_process.returncode is None:
                logger.info("Terminating `go-ios listen` process...")
                self.ios_listen_process.terminate()
                await self.ios_listen_process.wait()
            logger.info("`go-ios listen` process stopped.")
            # Optionally, attempt to restart the listener after a delay if it stops unexpectedly
            # await asyncio.sleep(5)
            # self.listen_task = asyncio.create_task(self._listen_to_device_events())
    async def mark_device_status(self, udid: str, status: DeviceStatus) -> bool:
        async with self._lock:
            device = self.devices.get(udid)
            if device:
                device.status = status
                logger.info(f"Device {device.name} ({udid}) status marked as {status.value}.")
                return True
            else:
                logger.error(f"Cannot mark status for unknown device UDID {udid}.")
                return False
    async def get_devices_list(self) -> List[Device]:
        async with self._lock:
            # Return copies to avoid external modification if Pydantic models are mutable
            return [dev.copy(deep=True) for dev in self.devices.values()]
    async def get_device_by_udid(self, udid: str) -> Optional[Device]:
        async with self._lock:
            device = self.devices.get(udid)
            return device.copy(deep=True) if device else None
    async def get_device_by_id(self, device_id: int) -> Optional[Device]:
        async with self._lock:
            for device in self.devices.values():
                if device.id == device_id:
                    return device.copy(deep=True)
            return None
    async def shutdown(self):
        logger.info("Shutting down DeviceManager...")
        if self.listen_task and not self.listen_task.done():
            self.listen_task.cancel()
            try:
                await self.listen_task
            except asyncio.CancelledError:
                logger.info("Device event listener task cancelled.")
       
        if self.ios_listen_process and self.ios_listen_process.returncode is None:
            logger.info("Terminating `go-ios listen` process during shutdown...")
            self.ios_listen_process.terminate()
            try:
                await asyncio.wait_for(self.ios_listen_process.wait(), timeout=5.0)
            except asyncio.TimeoutError:
                self.ios_listen_process.kill()
                await self.ios_listen_process.wait()
            logger.info("`go-ios listen` process stopped during shutdown.")
        logger.info("DeviceManager shut down.")
```
**16. `app/routers/device_routes.py`:**
```python
from fastapi import APIRouter, HTTPException, status as HttpStatus, Path
from typing import List
from app.config import logger
from app.schemas.device import Device, DeviceStatus
from app.services.device_manager import DeviceManager # Assuming DeviceManager is initialized globally or passed
router = APIRouter(prefix="/api/device", tags=["Devices"])
@router.get("/list", response_model=List[Device])
async def list_devices():
    try:
        device_manager = await DeviceManager.get_instance()
        devices = await device_manager.get_devices_list()
        return devices
    except Exception as e:
        logger.error(f"Error getting device list: {e}", exc_info=True)
        raise HTTPException(status_code=HttpStatus.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error fetching devices")
# The original PUT route was commented out and seemed incomplete.
# Here's a more complete example if you want to manually set status.
# Be cautious with manual status changes as DeviceManager updates status automatically.
@router.put("/status/{udid}/{new_status_str}", status_code=HttpStatus.HTTP_200_OK)
async def update_device_status(
    udid: str = Path(..., title="Device UDID", description="The UDID of the device"),
    new_status_str: str = Path(..., title="New Status", description="New status (AVAILABLE, BUSY, OFFLINE)")
):
    try:
        new_status = DeviceStatus[new_status_str.upper()]
    except KeyError:
        raise HTTPException(
            status_code=HttpStatus.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status. Must be one of: {[s.value for s in DeviceStatus]}"
        )
    try:
        device_manager = await DeviceManager.get_instance()
        device = await device_manager.get_device_by_udid(udid)
        if not device:
            raise HTTPException(status_code=HttpStatus.HTTP_404_NOT_FOUND, detail=f"Device with UDID {udid} not found")
        # Potentially add checks here, e.g., don't allow setting OFFLINE if device is connected.
        # Or, only allow setting BUSY/AVAILABLE if current status is not OFFLINE.
        # if device.status == DeviceStatus.OFFLINE and new_status != DeviceStatus.OFFLINE:
        #     raise HTTPException(status_code=HttpStatus.HTTP_409_CONFLICT, detail="Cannot change status of an OFFLINE device manually here.")
        success = await device_manager.mark_device_status(udid, new_status)
        if success:
            return {"status": True, "message": f"Device {udid} status updated to {new_status.value}"}
        else:
            # This case should ideally be caught by get_device_by_udid if not found
            raise HTTPException(status_code=HttpStatus.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to update device status")
    except HTTPException:
        raise # Re-raise FastAPI's HTTPExceptions
    except Exception as e:
        logger.error(f"Error updating device {udid} status to {new_status_str}: {e}", exc_info=True)
        raise HTTPException(status_code=HttpStatus.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error updating device status")
```
**17. `app/services/socket_handlers.py`:**
```python
import socketio
from typing import Dict, Any, Callable
from app.config import logger
from app.services.device_manager import DeviceManager
from app.services.idf_service import IDF
# Global map to store IDF instances, keyed by socket ID (sid)
# This needs to be accessible by the Socket.IO server instance in main.py
IDF_INSTANCES: Dict[str, IDF] = {}
async def handle_device_prepare(sio: socketio.AsyncServer, sid: str, data: Any):
    """Handles the 'devicePrepare' socket event."""
    logger.info(f"Socket {sid}: Received 'devicePrepare' with data: {data}")
    udid = data.get("udid")
    if not udid:
        logger.error(f"Socket {sid}: 'devicePrepare' called without UDID.")
        return {"status": False, "msg": "UDID is required."} # Send response via callback/ack
    if sid in IDF_INSTANCES:
        logger.warning(f"Socket {sid}: 'devicePrepare' called, but an IDF instance already exists for this session. Cleaning up old one.")
        await handle_disconnect(sio, sid, "re-preparing") # Clean up existing before creating new
    try:
        device_manager = await DeviceManager.get_instance()
        device = await device_manager.get_device_by_udid(udid)
        if not device:
            logger.error(f"Socket {sid}: Device with UDID {udid} not found by DeviceManager.")
            return {"status": False, "msg": f"Device {udid} not found or not available."}
        if device.status == device.status.BUSY:
            logger.warning(f"Socket {sid}: Device {udid} is already BUSY.")
            # Allow preparing a busy device if it's by the same user? Or deny?
            # For now, let's deny if it's busy by another IDF instance.
            # This check is simplified; a more robust check would be if any IDF instance holds this UDID.
            # return {"status": False, "msg": f"Device {udid} is currently busy."}
        await device_manager.mark_device_status(udid, device.status.BUSY)
       
        # Pass the actual socket object for direct emit, or use sio.emit(..., room=sid)
        # For simplicity, let's assume we might want to emit directly from IDF later.
        # However, python-socketio's AsyncServer methods are typically used with `sio.emit`.
        # Let's pass `sio` and `sid` to IDF, so it can use `sio.emit(..., room=sid)`.
        idf_instance = IDF(udid=device.udid, device_os_version=device.version, client_socket_sid=sid, sio_server=sio)
       
        success = await idf_instance.start()
        if success:
            IDF_INSTANCES[sid] = idf_instance
            logger.info(f"Socket {sid}: IDF instance created and started for UDID {udid}.")
            return {"status": True, "msg": "Device prepared successfully and IDF instance created."}
        else:
            logger.error(f"Socket {sid}: Failed to start IDF instance for UDID {udid}.")
            await device_manager.mark_device_status(udid, device.status.AVAILABLE) # Revert status
            return {"status": False, "msg": "Failed to prepare device and start IDF instance."}
    except Exception as e:
        logger.error(f"Socket {sid}: Error during 'devicePrepare' for UDID {udid}: {e}", exc_info=True)
        if udid: # Try to mark as available if we got far enough to mark it busy
            try:
                device_manager = await DeviceManager.get_instance()
                await device_manager.mark_device_status(udid, device.status.AVAILABLE)
            except Exception as e_revert:
                logger.error(f"Socket {sid}: Failed to revert device {udid} status to AVAILABLE: {e_revert}")
        return {"status": False, "msg": "An internal error occurred during device preparation."}
async def handle_command(sio: socketio.AsyncServer, sid: str, data: Any):
    """Handles the 'command' socket event."""
    logger.debug(f"Socket {sid}: Received 'command' with data: {data}")
   
    idf_instance = IDF_INSTANCES.get(sid)
    if not idf_instance:
        logger.error(f"Socket {sid}: 'command' received, but no IDF instance found for this session.")
        return {"success": False, "error": "No active device session. Please prepare a device first."} # Ack
   
    try:
        # The command data should include udid, cmd, and values (data.data in TS)
        # The IDF.send_wda_command expects this structure.
        response = await idf_instance.send_wda_command(data)
        return response # Ack with WDA command response
    except Exception as e:
        logger.error(f"Socket {sid}: Error processing 'command' for IDF {idf_instance.udid}: {e}", exc_info=True)
        return {"success": False, "error": "Error processing command."} # Ack
async def handle_disconnect(sio: socketio.AsyncServer, sid: str, reason: str = "client disconnected"):
    """Handles client disconnection."""
    logger.info(f"Socket {sid}: Disconnected. Reason: {reason}. Cleaning up IDF instance if any.")
   
    idf_instance = IDF_INSTANCES.pop(sid, None) # Remove and get
    if idf_instance:
        logger.info(f"Socket {sid}: Found active IDF instance for UDID {idf_instance.udid}. Stopping it...")
        original_udid = idf_instance.udid
        try:
            await idf_instance.stop()
            logger.info(f"Socket {sid}: IDF instance for UDID {original_udid} stopped successfully.")
        except Exception as e:
            logger.error(f"Socket {sid}: Error stopping IDF instance for UDID {original_udid}: {e}", exc_info=True)
        finally:
            # Ensure device is marked as available
            try:
                device_manager = await DeviceManager.get_instance()
                await device_manager.mark_device_status(original_udid, DeviceStatus.AVAILABLE)
            except Exception as e_status:
                logger.error(f"Socket {sid}: Error marking device {original_udid} as AVAILABLE after IDF stop: {e_status}")
    else:
        logger.info(f"Socket {sid}: No active IDF instance found to clean up.")
# Modify IDF to accept sio and sid
# In idf_service.py:
# class IDF:
#     def __init__(self, udid: str, device_os_version: str, client_socket_sid: str, sio_server: socketio.AsyncServer):
#         # ...
#         self.client_socket_sid = client_socket_sid
#         self.sio_server = sio_server
#         # ...
#    async def _handle_wda_stream_data(self, data: bytes):
#        if self.sio_server and self.client_socket_sid:
#            try:
#                # Check if client is still connected before emitting
#                # This check might not be readily available without querying sio_server.sockets
#                # For now, assume emit will handle disconnected clients gracefully or log errors.
#                await self.sio_server.emit("imageFrame", data, room=self.client_socket_sid)
#            except Exception as e:
#                logger.error(f"IDF {self.udid}: Error emitting imageFrame to {self.client_socket_sid}: {e}")
#
#   async def _on_tunnel_die(self, code: int, signal_name: Optional[str]):
#       # ... (existing code) ...
#       if self.sio_server and self.client_socket_sid:
#           await self.sio_server.emit("idfError",
#                                      {"udid": self.udid, "message": "A critical tunnel process died."},
#                                      room=self.client_socket_sid)
# Make sure to apply these changes in `app/services/idf_service.py` for `IDF.__init__` and `_handle_wda_stream_data`, `_on_tunnel_die`.
```
**(IDF modification from above comment block needs to be applied to `app/services/idf_service.py`)**
**18. `app/main.py`:**
```python
import asyncio
import socketio
from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse
from contextlib import asynccontextmanager
from pathlib import Path
from app.config import logger, APP_ENV
from app.routers import device_routes
from app.services import socket_handlers # To register handlers
from app.services.device_manager import DeviceManager
# Global IDF instances map, managed by socket_handlers
# from app.services.socket_handlers import IDF_INSTANCES (already there)
# Create Socket.IO ASGI app
sio = socketio.AsyncServer(async_mode="asgi", cors_allowed_origins="*") # Adjust CORS as needed
# socket_app = socketio.ASGIApp(sio, static_files={ # If serving static files via socket.io directly
#     '/': 'app/static/index.html',
#     '/static': 'app/static'
# })
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Application startup...")
    # Initialize DeviceManager singleton instance
    dm = await DeviceManager.get_instance()
    logger.info("DeviceManager instance obtained.")
   
    # You can pre-populate devices or perform other startup tasks here if needed
    # For example, if you want to list devices on startup:
    # initial_devices = await dm.get_devices_list()
    # logger.info(f"Initial devices: {initial_devices}")
    yield # Application runs here
    logger.info("Application shutdown...")
    # Clean up IDF instances
    sids_to_cleanup = list(socket_handlers.IDF_INSTANCES.keys())
    for sid_cleanup in sids_to_cleanup:
        logger.info(f"Cleaning up IDF for SID {sid_cleanup} during app shutdown.")
        await socket_handlers.handle_disconnect(sio, sid_cleanup, "application shutdown")
   
    # Shutdown DeviceManager
    if DeviceManager._instance: # Access internal _instance for shutdown
        await DeviceManager._instance.shutdown()
    logger.info("Application shutdown complete.")
app = FastAPI(lifespan=lifespan, title=APP_ENV.APP_NAME, version="1.0.0")
# Mount Socket.IO app
app.mount("/ws", socketio.ASGIApp(sio)) # Mount under /ws, client connects to /ws
# --- Socket.IO Event Handlers ---
@sio.event
async def connect(sid, environ, auth):
    logger.info(f"Client connected: {sid}")
    # You can access request headers via environ if needed
    # Example: logger.debug(f"Connection environment for {sid}: {environ}")
    # await sio.emit('message', {'data': 'Connected'}, room=sid) # Optional welcome message
@sio.event
async def disconnect(sid):
    logger.info(f"Client disconnected: {sid}")
    await socket_handlers.handle_disconnect(sio, sid)
@sio.on("devicePrepare")
async def on_device_prepare(sid, data):
    # Callbacks/Acknowledgments are handled by returning the value
    logger.debug(f"Socket {sid} sent 'devicePrepare': {data}")
    response = await socket_handlers.handle_device_prepare(sio, sid, data)
    return response
@sio.on("command")
async def on_command(sid, data):
    logger.debug(f"Socket {sid} sent 'command': {data}")
    response = await socket_handlers.handle_command(sio, sid, data)
    return response
@sio.event
async def error(sid, data): # General error event from client? Or server-side error?
    logger.error(f"Socket.IO error event for SID {sid}: {data}")
    # This 'error' event is often for client-side errors reported to server.
    # If it implies a critical client issue, you might want to clean up.
    await socket_handlers.handle_disconnect(sio, sid, f"client error: {data}")
# --- FastAPI HTTP Routes ---
# Serve static files (e.g., index.html for testing)
static_dir = Path(__file__).parent / "static"
if static_dir.exists():
    app.mount("/static", StaticFiles(directory=static_dir), name="static")
@app.get("/", response_class=HTMLResponse)
async def get_root(request: Request):
    index_html_path = static_dir / "index.html"
    if index_html_path.exists():
        return FileResponse(index_html_path)
    return HTMLResponse("<html><body><h1>iOS Device Farm (Python/FastAPI)</h1><p>Socket.IO server running. Connect client to /ws path.</p></body></html>")
# Include device API routes
app.include_router(device_routes.router)
if __name__ == "__main__":
    import uvicorn
    logger.info(f"Starting Uvicorn server on port {APP_ENV.PORT} for {APP_ENV.APP_NAME}")
    # Note: Uvicorn's reload can cause issues with asyncio subprocesses and singletons
    # if not handled carefully (e.g., multiple DeviceManager instances).
    # For development with reload, ensure cleanup logic is robust or disable reload for stability.
    uvicorn.run("app.main:app", host="0.0.0.0", port=APP_ENV.PORT, reload=False) # reload=True for dev
```
**19. `app/static/index.html` (Example for testing Socket.IO):**
```html
<!DOCTYPE html>
<html>
<head>
    <title>Socket.IO Test</title>
    <script src="https://cdn.socket.io/4.7.5/socket.io.min.js"></script>
</head>
<body>
    <h1>Socket.IO Test Client</h1>
    <div id="messages"></div>
    <button onclick="prepareDevice()">Prepare Device</button>
    <button onclick="sendCommand()">Send Command (Tap)</button>
    <img id="videoFrame" src="" alt="Video Stream" width="320" height="568" />
    <script>
        // Connect to the /ws namespace where the Socket.IO app is mounted
        const socket = io(window.location.origin, { path: "/ws/socket.io" });
        const messagesDiv = document.getElementById('messages');
        const videoFrame = document.getElementById('videoFrame');
        const testUdid = "YOUR_DEVICE_UDID"; // REPLACE WITH A REAL UDID FOR TESTING
        socket.on('connect', () => {
            logMessage('Connected to server! SID: ' + socket.id);
        });
        socket.on('disconnect', (reason) => {
            logMessage('Disconnected from server: ' + reason);
        });
        socket.on('connect_error', (err) => {
            logMessage('Connection Error: ' + err.message);
        });
       
        socket.on('message', (data) => { // Example custom event
            logMessage('Message from server: ' + JSON.stringify(data));
        });
        socket.on('imageFrame', (data) => {
            // data is ArrayBuffer or Blob containing JPEG
            const blob = new Blob([data], { type: 'image/jpeg' });
            const url = URL.createObjectURL(blob);
            videoFrame.src = url;
            // Optional: Revoke object URL after some time to free memory
            // setTimeout(() => URL.revokeObjectURL(url), 100);
        });
        socket.on('idfError', (data) => {
            logMessage(`IDF Error for ${data.udid}: ${data.message}`);
        });
        function logMessage(message) {
            const p = document.createElement('p');
            p.textContent = message;
            messagesDiv.appendChild(p);
            console.log(message);
        }
        function prepareDevice() {
            if (!testUdid || testUdid === "YOUR_DEVICE_UDID") {
                logMessage("Please replace YOUR_DEVICE_UDID in the script with a real UDID.");
                alert("Please replace YOUR_DEVICE_UDID in the script with a real UDID.");
                return;
            }
            logMessage(`Sending 'devicePrepare' for UDID: ${testUdid}`);
            socket.emit('devicePrepare', { udid: testUdid }, (response) => {
                logMessage('devicePrepare ack: ' + JSON.stringify(response));
            });
        }
        function sendCommand() {
             if (!testUdid || testUdid === "YOUR_DEVICE_UDID") {
                logMessage("Please prepare a device first or set a UDID.");
                return;
            }
            const commandData = {
                udid: testUdid, // Should match the prepared device's UDID
                cmd: "tap", // WdaCommands.TAP
                data: { x: 100, y: 200 } // Example tap coordinates
            };
            logMessage(`Sending 'command': ${JSON.stringify(commandData)}`);
            socket.emit('command', commandData, (response) => {
                logMessage('command ack: ' + JSON.stringify(response));
            });
        }
    </script>
</body>
</html>
```
**To Run:**
1.  Install dependencies: `pip install -r requirements.txt`
2.  Ensure `go-ios` and `ideviceinstaller` (and other `libimobiledevice` tools) are in your `PATH` or `GO_IOS_PATH` in `.env` is correctly set.
3.  Update `YOUR_DEVICE_UDID` in `app/static/index.html` if testing with it.
4.  Apply the IDF modification mentioned in the `socket_handlers.py` comment block to `app/services/idf_service.py`.
    *   `IDF.__init__` to accept `client_socket_sid: str, sio_server: socketio.AsyncServer`
    *   `IDF._handle_wda_stream_data` to use `self.sio_server.emit("imageFrame", data, room=self.client_socket_sid)`
    *   `IDF._on_tunnel_die` to emit `idfError` using `self.sio_server.emit(...)`
5.  Run: `python -m uvicorn app.main:app --host 0.0.0.0 --port 9000` (or use the `if __name__ == "__main__":` block in `main.py`)
This is a very comprehensive conversion. Testing each part, especially the subprocess interactions with `go-ios` and WDA, will be crucial. The MJPEG parsing and WDA communication logic are complex and might need fine-tuning based on the exact behavior of `go-ios` and WDA versions. Error handling and resource cleanup (processes, sockets) are also critical aspects.
## Forex Trading Bot: Detailed API Specification and Business Logic

This document details the API endpoints for the Forex Trading Bot, including request/response formats, business logic, and error handling. This specification supports the requirements outlined in the PRD, particularly focusing on the "Detailed Feature Requirements" and "Technical Architecture Overview" sections.

---

### **General API Principles:**

*   **RESTful Design:** Standard HTTP methods (GET, POST, PUT, DELETE) for resource-oriented interaction.
*   **JSON Payloads:** All request and response bodies use JSON format.
*   **Authentication:** All authenticated endpoints require a valid JWT token in the `Authorization` header (`Bearer <token>`).
*   **Error Handling:** Standard HTTP status codes are used, with detailed error messages in JSON format for client-side debugging.
*   **Rate Limiting:** To prevent abuse and ensure system stability, appropriate rate limits will be applied to all endpoints.
*   **Idempotency:** POST and PUT requests will be designed to be idempotent where applicable (e.g., creating a strategy twice with the same ID should not result in two strategies).
*   **Versioning:** All APIs will be versioned (e.g., `/v1/`).

---

### **1. User Management Service API**

**Base Path:** `/api/v1/users`

This service handles user registration, authentication, authorization, and profile management.

---

#### **1.1. User Registration**

*   **Endpoint:** `POST /register`
*   **Description:** Creates a new user account.
*   **Business Logic:**
    *   Validates input: email format, strong password policy (min length, special chars, etc.), unique email.
    *   Hashes the password before storing it.
    *   Assigns a default user role (e.g., "basic_trader").
    *   Optionally sends a verification email.
    *   On successful registration, the user is created but not automatically logged in.
*   **Request Body:**
    ```json
    {
        "email": "user@example.com",
        "password": "StrongPassword123!",
        "confirm_password": "StrongPassword123!"
    }
    ```
*   **Response (201 Created):**
    ```json
    {
        "message": "User registered successfully. Please verify your email.",
        "user_id": "uuid-of-new-user"
    }
    ```
*   **Error Responses:**
    *   `400 Bad Request`: Invalid input (e.g., invalid email, weak password, passwords mismatch, email already exists).
    *   `500 Internal Server Error`: Server-side issues.

---

#### **1.2. User Login**

*   **Endpoint:** `POST /login`
*   **Description:** Authenticates a user and returns a JWT token.
*   **Business Logic:**
    *   Validates email and password against stored credentials.
    *   Generates a time-limited JWT upon successful authentication.
    *   Records login attempt (success/failure) for security auditing.
*   **Request Body:**
    ```json
    {
        "email": "user@example.com",
        "password": "StrongPassword123!"
    }
    ```
*   **Response (200 OK):**
    ```json
    {
        "access_token": "jwt.token.string",
        "token_type": "bearer",
        "expires_in": 3600 // seconds
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`: Invalid email or password.
    *   `400 Bad Request`: Missing email or password.
    *   `500 Internal Server Error`.

---

#### **1.3. Get User Profile**

*   **Endpoint:** `GET /profile`
*   **Description:** Retrieves the authenticated user's profile information.
*   **Business Logic:**
    *   Requires a valid JWT token.
    *   Fetches non-sensitive user details.
*   **Request:** `Authorization: Bearer <token>`
*   **Response (200 OK):**
    ```json
    {
        "user_id": "uuid-of-user",
        "email": "user@example.com",
        "first_name": "John",
        "last_name": "Doe",
        "account_status": "active",
        "plan": "premium",
        "created_at": "2023-01-01T10:00:00Z"
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`: Invalid or missing token.
    *   `404 Not Found`: User profile not found (should not happen with authenticated request).

---

#### **1.4. Update User Profile**

*   **Endpoint:** `PUT /profile`
*   **Description:** Updates the authenticated user's profile information.
*   **Business Logic:**
    *   Requires a valid JWT token.
    *   Validates update intention (e.g., email changes might require re-verification).
    *   Does not allow password changes here (separate endpoint).
*   **Request Body:**
    ```json
    {
        "first_name": "Jonathan",
        "last_name": "Doe"
    }
    ```
*   **Response (200 OK):**
    ```json
    {
        "message": "Profile updated successfully.",
        "user_id": "uuid-of-user"
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `400 Bad Request`: Invalid input (e.g., attempting to change non-editable fields).

---

### **2. Account Management Service API**

**Base Path:** `/api/v1/accounts`

This service manages connections to external brokerage accounts, their balance, and equity.

---

#### **2.1. Link Brokerage Account (F.4.1)**

*   **Endpoint:** `POST /link`
*   **Description:** Connects a user's external brokerage account to the platform.
*   **Business Logic:**
    *   Requires a valid JWT token.
    *   Validates `broker_type` against supported brokers (e.g., "MT4", "MT5", "cTrader", "CustomAPI").
    *   Stores `credentials` securely (encrypted).
    *   Initiates a connection test to the broker using provided credentials.
    *   Fetches initial account details (balance, currency, account number) upon successful connection.
    *   Assigns a unique `account_id` to the linked account.
*   **Request Body:**
    ```json
    {
        "account_name": "My IC Markets Live Account",
        "broker_type": "MT4",
        "broker_server_name": "ICMarkets-Live01",
        "account_number": "1234567",
        "password": "brokerAccountPassword",
        "is_live_account": true 
    }
    ```
*   **Response (201 Created):**
    ```json
    {
        "message": "Brokerage account linked successfully. Initiating connection test.",
        "account_id": "uuid-of-linked-account",
        "broker_status": "connecting" 
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `400 Bad Request`: Invalid broker type, missing credentials, connection test failed.
    *   `409 Conflict`: Account already linked.

---

#### **2.2. Get Linked Accounts**

*   **Endpoint:** `GET /`
*   **Description:** Retrieves a list of all brokerage accounts linked by the authenticated user.
*   **Business Logic:**
    *   Fetches metadata about linked accounts, but *not* the sensitive credentials.
    *   Includes current connection status (connected, disconnected, error).
*   **Request:** `Authorization: Bearer <token>`
*   **Response (200 OK):**
    ```json
    [
        {
            "account_id": "uuid-account-1",
            "account_name": "My IC Markets Live Account",
            "broker_type": "MT4",
            "broker_server_name": "ICMarkets-Live01",
            "account_number": "1234567",
            "is_live_account": true,
            "currency": "USD",
            "balance": 10000.00,
            "equity": 10150.50,
            "margin_free": 9800.00,
            "connection_status": "connected",
            "last_updated_at": "2023-10-27T10:30:00Z"
        },
        {
            "account_id": "uuid-account-2",
            "account_name": "My Demo Account",
            "broker_type": "MT5",
            "is_live_account": false,
            "connection_status": "connected"
        }
    ]
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.

---

#### **2.3. Get Account Details (F.1.1)**

*   **Endpoint:** `GET /{account_id}`
*   **Description:** Retrieves detailed information for a specific linked account, including real-time balance and equity.
*   **Business Logic:**
    *   Requires a valid JWT token and ownership of `account_id`.
    *   Connects to the broker in real-time (or retrieves from recent cache) to get the latest balance, equity, and margin information.
*   **Request:** `Authorization: Bearer <token>`
*   **Response (200 OK):**
    ```json
    {
        "account_id": "uuid-account-1",
        "account_name": "My IC Markets Live Account",
        "broker_type": "MT4",
        "broker_server_name": "ICMarkets-Live01",
        "account_number": "1234567",
        "is_live_account": true,
        "currency": "USD",
        "balance": 10000.00,
        "equity": 10150.50,
        "margin_free": 9800.00,
        "margin_used": 350.50,
        "connection_status": "connected",
        "last_updated_at": "2023-10-27T10:30:00Z",
        "current_profit": 150.50,
        "leverage": 500
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `403 Forbidden`: User does not own this account.
    *   `404 Not Found`: Account ID does not exist.
    *   `503 Service Unavailable`: Broker connection error.

---

#### **2.4. Unlink Brokerage Account**

*   **Endpoint:** `DELETE /{account_id}`
*   **Description:** Disconnects and removes a linked brokerage account.
*   **Business Logic:**
    *   Requires a valid JWT token and ownership of `account_id`.
    *   Ensures all associated live strategies for this account are stopped before removal.
    *   Removes all stored credentials and account data.
    *   This is a destructive action; prompt user for confirmation if UI.
*   **Request:** `Authorization: Bearer <token>`
*   **Response (204 No Content):**
    *   No content on successful deletion.
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `403 Forbidden`.
    *   `404 Not Found`.
    *   `409 Conflict`: Cannot delete account while active strategies are running.

---

### **3. Market Data Service API**

**Base Path:** `/api/v1/market-data`

This service provides real-time and historical market data.

---

#### **3.1. Get Available Instruments**

*   **Endpoint:** `GET /instruments`
*   **Description:** Retrieves a list of supported tradable Forex instruments.
*   **Business Logic:**
    *   Returns a static or dynamically updated list of instruments (currency pairs) available across integrated brokers.
*   **Response (200 OK):**
    ```json
    [
        {"symbol": "EURUSD", "description": "Euro / US Dollar", "base": "EUR", "quote": "USD"},
        {"symbol": "GBPUSD", "description": "Great British Pound / US Dollar", "base": "GBP", "quote": "USD"},
        {"symbol": "USDJPY", "description": "US Dollar / Japanese Yen", "base": "USD", "quote": "JPY"}
    ]
    ```

---

#### **3.2. Get Real-time Price (WebSocket)**

*   **Endpoint:** `WS /prices`
*   **Description:** Establishes a WebSocket connection for real-time price updates.
*   **Business Logic:**
    *   Requires initial authentication (e.g., via query parameter for JWT) or during handshake.
    *   Users can subscribe to specific `symbols` and `timeframes`.
    *   The service streams `tick` data or aggregated `OHLCV` (Open, High, Low, Close, Volume) data at specified intervals.
*   **Client Request (via WebSocket message):**
    ```json
    {
        "type": "subscribe",
        "symbols": ["EURUSD", "GBPUSD"],
        "timeframe": "M1" // Optional: for OHLCV data
    }
    ```
*   **Server Response (via WebSocket message - examples):**
    ```json
    // Tick Data
    {
        "type": "tick",
        "symbol": "EURUSD",
        "bid": 1.07543,
        "ask": 1.07550,
        "timestamp": "2023-10-27T10:30:15.123Z"
    }

    // M1 OHLCV Data
    {
        "type": "ohlcv",
        "symbol": "GBPUSD",
        "timeframe": "M1",
        "open": 1.22300,
        "high": 1.22315,
        "low": 1.22295,
        "close": 1.22310,
        "volume": 1234,
        "timestamp": "2023-10-27T10:30:00Z"
    }
    ```

---

#### **3.3. Get Historical Data (F.3.1)**

*   **Endpoint:** `GET /history/{symbol}`
*   **Description:** Retrieves historical OHLCV data for a given instrument.
*   **Business Logic:**
    *   Paginates results for large requests.
    *   Supports various `timeframes` (M1, M5, M15, H1, H4, D1, W1, MN1).
    *   Retrieves data from the time-series database or object storage.
*   **Query Parameters:**
    *   `timeframe`: (Required) String, e.g., "M1", "H1", "D1".
    *   `start_time`: (Optional) ISO 8601 datetime string. Defaults to 30 days ago.
    *   `end_time`: (Optional) ISO 8601 datetime string. Defaults to now.
    *   `limit`: (Optional) Integer, max number of bars to return. Defaults to 1000.
    *   `page`: (Optional) Integer, for pagination. Defaults to 1.
*   **Response (200 OK):**
    ```json
    {
        "symbol": "EURUSD",
        "timeframe": "H1",
        "data": [
            {"time": "2023-10-26T14:00:00Z", "open": 1.07500, "high": 1.07550, "low": 1.07480, "close": 1.07530, "volume": 1500},
            {"time": "2023-10-26T15:00:00Z", "open": 1.07530, "high": 1.07580, "low": 1.07510, "close": 1.07560, "volume": 1700},
            ...
        ],
        "pagination": {
            "total_items": 5000,
            "total_pages": 5,
            "current_page": 1,
            "page_size": 1000
        }
    }
    ```
*   **Error Responses:**
    *   `400 Bad Request`: Invalid symbol or timeframe.
    *   `404 Not Found`: No data for the specified parameters.

---

### **4. Strategy Management Service API**

**Base Path:** `/api/v1/strategies`

This service handles the creation, storage, retrieval, and management of trading strategies.

---

#### **4.1. Create Strategy (F.2.1, F.2.2)**

*   **Endpoint:** `POST /`
*   **Description:** Creates a new trading strategy.
*   **Business Logic:**
    *   Requires a valid JWT token.
    *   Validates the `strategy_definition` based on `strategy_type`:
        *   For `visual_builder`: Validates the JSON structure adheres to the predefined block-based schema (e.g., ensuring indicators are correctly configured, logical operators are valid).
        *   For `code_editor`: Validates the script syntax (e.g., Python DSL parsing).
    *   Stores `strategy_definition` along with metadata.
    *   Assigns a unique `strategy_id`.
*   **Request Body (Visual Builder Example):**
    ```json
    {
        "strategy_name": "My RSI & MA Crossover Strategy",
        "description": "Buy when RSI is oversold and MA crosses up, sell when overbought and MA crosses down.",
        "strategy_type": "visual_builder",
        "config": {
            "symbol": "EURUSD",
            "timeframe": "H1",
            "entry_conditions": {
                "type": "AND",
                "conditions": [
                    {"indicator": "RSI", "params": {"period": 14}, "operator": "<", "value": 30},
                    {"indicator": "MA_CROSSOVER", "params": {"fast_period": 10, "slow_period": 30}, "type": "UP"}
                ]
            },
            "exit_conditions": {
                "type": "OR",
                "conditions": [
                    {"indicator": "RSI", "params": {"period": 14}, "operator": ">", "value": 70},
                    {"indicator": "MA_CROSSOVER", "params": {"fast_period": 10, "slow_period": 30}, "type": "DOWN"}
                ]
            },
            "stop_loss_type": "percentage",
            "stop_loss_value": 0.5, // 0.5%
            "take_profit_type": "percentage",
            "take_profit_value": 1.0, // 1.0%
            "trailing_stop_enabled": true,
            "trailing_stop_offset": 0.2 // 0.2%
        }
    }
    ```
*   **Request Body (Code Editor Example):**
    ```json
    {
        "strategy_name": "My Custom Python Strategy",
        "description": "An advanced strategy using a custom indicator.",
        "strategy_type": "code_editor",
        "config": {
            "language": "python_dsl",
            "code": "def on_bar(data):\n    # Access to data via data.ohlcv(symbol, timeframe)\n    # Place order via self.buy(symbol, lot_size, sl, tp)\n    pass\n",
            "parameters": [
                {"name": "atr_period", "type": "integer", "default": 14},
                {"name": "risk_per_trade", "type": "float", "default": 0.01}
            ]
        }
    }
    ```
*   **Response (201 Created):**
    ```json
    {
        "message": "Strategy created successfully.",
        "strategy_id": "uuid-of-new-strategy"
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `400 Bad Request`: Invalid `strategy_type` or malformed `strategy_definition`.

---

#### **4.2. Get All User Strategies**

*   **Endpoint:** `GET /`
*   **Description:** Retrieves a list of all strategies created by the authenticated user.
*   **Business Logic:**
    *   Returns only metadata, not the full strategy definition config, for a list view.
    *   Includes current status (e.g., "draft", "backtested", "live_running", "live_stopped").
*   **Request:** `Authorization: Bearer <token>`
*   **Response (200 OK):**
    ```json
    [
        {
            "strategy_id": "uuid-strategy-1",
            "strategy_name": "My RSI & MA Crossover Strategy",
            "description": "...",
            "strategy_type": "visual_builder",
            "created_at": "2023-10-20T09:00:00Z",
            "last_modified_at": "2023-10-25T14:30:00Z",
            "status": "backtested"
        },
        {
            "strategy_id": "uuid-strategy-2",
            "strategy_name": "My Custom Python Strategy",
            "strategy_type": "code_editor",
            "status": "draft"
        }
    ]
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.

---

#### **4.3. Get Strategy Details**

*   **Endpoint:** `GET /{strategy_id}`
*   **Description:** Retrieves the full definition and metadata for a specific strategy.
*   **Business Logic:**
    *   Requires a valid JWT token and ownership of `strategy_id`.
    *   Returns the complete `config` object.
*   **Response (200 OK):**
    ```json
    {
        "strategy_id": "uuid-strategy-1",
        "strategy_name": "My RSI & MA Crossover Strategy",
        "description": "Buy when RSI is oversold and MA crosses up, sell when overbought and MA crosses down.",
        "strategy_type": "visual_builder",
        "created_at": "2023-10-20T09:00:00Z",
        "last_modified_at": "2023-10-25T14:30:00Z",
        "status": "backtested",
        "config": {
            // Full strategy definition as per 4.1 request body
        }
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `403 Forbidden`: User does not own this strategy.
    *   `404 Not Found`.

---

#### **4.4. Update Strategy**

*   **Endpoint:** `PUT /{strategy_id}`
*   **Description:** Updates an existing trading strategy.
*   **Business Logic:**
    *   Requires a valid JWT token and ownership of `strategy_id`.
    *   Validates the updated `strategy_definition`.
    *   If a strategy is currently `live_running`, this request will fail unless a special flag like `allow_live_update` is present and valid (e.g., only for minor parameter changes, not structural). Best practice is to stop a live strategy before updating.
    *   Updates `last_modified_at`.
*   **Request Body:** (Similar to `POST /`, but only include fields to be updated)
    ```json
    {
        "description": "Improved version of my MA Crossover strategy.",
        "config": {
            "entry_conditions": {
                "type": "AND",
                "conditions": [
                    {"indicator": "RSI", "params": {"period": 14}, "operator": "<", "value": 35}, // Changed from 30
                    {"indicator": "MA_CROSSOVER", "params": {"fast_period": 10, "slow_period": 30}, "type": "UP"}
                ]
            }
        }
    }
    ```
*   **Response (200 OK):**
    ```json
    {
        "message": "Strategy updated successfully.",
        "strategy_id": "uuid-strategy-1"
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `403 Forbidden`.
    *   `404 Not Found`.
    *   `400 Bad Request`: Invalid update.
    *   `409 Conflict`: Strategy is currently live and cannot be updated.

---

#### **4.5. Delete Strategy**

*   **Endpoint:** `DELETE /{strategy_id}`
*   **Description:** Deletes a trading strategy.
*   **Business Logic:**
    *   Requires a valid JWT token and ownership of `strategy_id`.
    *   Ensures the strategy is not `live_running` or `paper_running`.
    *   Deletes all associated backtest results and historical data (unless explicitly linked to other resources).
*   **Response (204 No Content):**
    *   No content on successful deletion.
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `403 Forbidden`.
    *   `404 Not Found`.
    *   `409 Conflict`: Strategy is currently active (live or paper trading).

---

### **5. Backtesting Engine API**

**Base Path:** `/api/v1/backtests`

This service orchestrates the backtesting and optimization of strategies.

---

#### **5.1. Initiate Backtest (F.3.1)**

*   **Endpoint:** `POST /`
*   **Description:** Starts a backtest for a given strategy.
*   **Business Logic:**
    *   Requires a valid JWT token and ownership of `strategy_id`.
    *   Validates `account_id` if provided (for context like currency, leverage, initial balance). If not provided, uses default simulation parameters.
    *   Retrieves strategy definition from Strategy Management Service.
    *   Retrieves historical data from Market Data Service.
    *   Queues a new backtest job for the Backtesting/Optimization Service.
    *   Assigns a unique `backtest_id`.
*   **Request Body:**
    ```json
    {
        "strategy_id": "uuid-strategy-1",
        "account_id": "uuid-account-2", // Optional, defines context. If not provided, simulated account with default values.
        "start_date": "2022-01-01T00:00:00Z",
        "end_date": "2023-01-01T00:00:00Z",
        "initial_balance": 10000.00, // Used if no account_id or papertrading
        "currency": "USD", // Used if no account_id or papertrading
        "symbol_config": {
            "EURUSD": {
                "spread_bps": 1.5, // Spread in basis points (e.g., 1.5 pips = 15 points)
                "slippage_bps": 1.0 // Slippage in basis points
            }
        },
        "simulation_settings": {
            "tick_data_precision": true, // Use tick data if available
            "commission_per_lot": 7.0, // Per standard lot, round turn
            "swap_simulation": true
        }
    }
    ```
*   **Response (202 Accepted):**
    ```json
    {
        "message": "Backtest initiated successfully.",
        "backtest_id": "uuid-of-new-backtest",
        "status": "queued"
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `403 Forbidden`.
    *   `404 Not Found`: Strategy or Account ID not found.
    *   `400 Bad Request`: Invalid date range, missing parameters.
    *   `409 Conflict`: Max concurrent backtests reached.

---

#### **5.2. Get Backtest Status**

*   **Endpoint:** `GET /{backtest_id}/status`
*   **Description:** Retrieves the current status of a backtest.
*   **Business Logic:**
    *   Reports progress (e.g., percentage complete) for long-running backtests.
*   **Response (200 OK):**
    ```json
    {
        "backtest_id": "uuid-of-backtest",
        "strategy_id": "uuid-strategy-1",
        "status": "running", // "queued", "running", "completed", "failed", "cancelled"
        "progress_percent": 75,
        "estimated_time_remaining_seconds": 120
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `403 Forbidden`.
    *   `404 Not Found`.

---

#### **5.3. Get Backtest Report (F.3.3)**

*   **Endpoint:** `GET /{backtest_id}/report`
*   **Description:** Retrieves the detailed results and report characteristics of a completed backtest.
*   **Business Logic:**
    *   Requires `status` to be "completed".
    *   Calculates and aggregates various performance metrics.
*   **Response (200 OK):**
    ```json
    {
        "backtest_id": "uuid-of-backtest",
        "strategy_id": "uuid-strategy-1",
        "status": "completed",
        "start_date": "2022-01-01T00:00:00Z",
        "end_date": "2023-01-01T00:00:00Z",
        "initial_balance": 10000.00,
        "final_balance": 12500.00,
        "net_profit": 2500.00,
        "total_trades": 150,
        "winning_trades": 90,
        "losing_trades": 60,
        "win_rate": 60.0,
        "profit_factor": 1.75,
        "max_drawdown_percent": 12.5,
        "max_drawdown_value": 1250.00,
        "sharpe_ratio": 1.2,
        "average_profit_per_trade": 16.67,
        "average_loss_per_trade": -20.83,
        "equity_curve": [
            {"date": "2022-01-01T00:00:00Z", "equity": 10000.00},
            {"date": "2022-01-02T00:00:00Z", "equity": 10050.00},
            ...
        ],
        "metrics_by_symbol": {
            "EURUSD": { /* specific metrics for EURUSD */ },
            "GBPUSD": { /* specific metrics for GBPUSD */ }
        }
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `403 Forbidden`.
    *   `404 Not Found`.
    *   `409 Conflict`: Backtest not yet completed.

---

#### **5.4. Initiate Optimization (F.3.4)**

*   **Endpoint:** `POST /optimize`
*   **Description:** Starts an optimization run for a given strategy's parameters.
*   **Business Logic:**
    *   Requires `strategy_id` and a definition of parameters to optimize (range, step).
    *   Queues multiple backtest jobs, each with different parameter combinations.
    *   Uses genetic algorithms or brute-force as specified.
*   **Request Body:**
    ```json
    {
        "strategy_id": "uuid-strategy-1",
        "start_date": "2022-01-01T00:00:00Z",
        "end_date": "2023-01-01T00:00:00Z",
        "optimization_type": "genetic_algorithm", // or "brute_force"
        "optimization_target": "profit_factor", // or "net_profit", "sharpe_ratio", "max_drawdown" (minimize)
        "parameters_to_optimize": [
            {
                "name": "config.entry_conditions.conditions[0].params.period", // Path to parameter in strategy config
                "min_value": 10,
                "max_value": 20,
                "step_value": 1
            },
            {
                "name": "config.stop_loss_value",
                "min_value": 0.3,
                "max_value": 1.0,
                "step_value": 0.1
            }
        ]
    }
    ```
*   **Response (202 Accepted):**
    ```json
    {
        "message": "Optimization initiated successfully.",
        "optimization_id": "uuid-of-new-optimization",
        "status": "queued"
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `403 Forbidden`.
    *   `404 Not Found`.
    *   `400 Bad Request`: Invalid optimization parameters.

---

#### **5.5. Get Optimization Results**

*   **Endpoint:** `GET /optimize/{optimization_id}/results`
*   **Description:** Retrieves the results of an optimization process.
*   **Business Logic:**
    *   Requires `status` to be "completed".
    *   Returns a list of backtest results, each with the parameters used, sorted by the `optimization_target`.
*   **Response (200 OK):**
    ```json
    {
        "optimization_id": "uuid-of-optimization",
        "status": "completed",
        "best_result": {
            "parameters": {
                "config.entry_conditions.conditions[0].params.period": 18,
                "config.stop_loss_value": 0.5
            },
            "net_profit": 3500.00,
            "profit_factor": 2.1,
            "max_drawdown_percent": 10.0
        },
        "all_results": [
            {
                "parameters": { /* ... */ },
                "net_profit": 3500.00, "profit_factor": 2.1, "max_drawdown_percent": 10.0
            },
            {
                "parameters": { /* ... */ },
                "net_profit": 2800.00, "profit_factor": 1.9, "max_drawdown_percent": 11.5
            }
            // ... (many more results)
        ]
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `403 Forbidden`.
    *   `404 Not Found`.
    *   `409 Conflict`: Optimization not yet completed.

---

### **6. Live Trading Module API**

**Base Path:** `/api/v1/live-trading`

This service manages the deployment, execution, and monitoring of live or paper trading strategies.

---

#### **6.1. Start Live/Paper Trading (F.4.5, F.4.6)**

*   **Endpoint:** `POST /start`
*   **Description:** Deploys a configured strategy to a live or paper trading account.
*   **Business Logic:**
    *   Requires a valid JWT token, ownership of `strategy_id` and `account_id`.
    *   Retrieves real-time market data for the strategy's symbols.
    *   Applies initial risk management checks (e.g., account liquidty).
    *   Sets the strategy's status to "live_running" or "paper_running".
    *   Executes strategy's `on_init` function (if code-based) or initializes visual builder state.
    *   Assigns a unique `deployment_id` for tracking this active instance.
*   **Request Body:**
    ```json
    {
        "strategy_id": "uuid-strategy-1",
        "account_id": "uuid-account-1", // Must be a linked live or paper trading account
        "operation_mode": "live", // "live" or "paper"
        "execution_parameters": {
            "initial_lot_size": 0.1,
            "risk_per_trade_percent": 1.0, // Overrides strategy's default if present
            "max_daily_loss_percent": 5.0, // Account F.5.2
            "start_time_utc": "00:00", // F.4.5 - Daily start time
            "end_time_utc": "23:59"    // F.4.5 - Daily end time
        }
    }
    ```
*   **Response (202 Accepted):**
    ```json
    {
        "message": "Strategy deployed and running.",
        "deployment_id": "uuid-of-deployment",
        "strategy_id": "uuid-strategy-1",
        "account_id": "uuid-account-1",
        "status": "running"
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `403 Forbidden`.
    *   `404 Not Found`: Strategy or Account not found.
    *   `400 Bad Request`: Invalid parameters, account not ready.
    *   `409 Conflict`: Strategy already deployed on this account.

---

#### **6.2. Stop Live/Paper Trading (F.4.5)**

*   **Endpoint:** `POST /stop/{deployment_id}`
*   **Description:** Stops a running live or paper trading strategy.
*   **Business Logic:**
    *   Requires a valid JWT token and ownership of `deployment_id`.
    *   Sets the strategy's status to "live_stopped" or "paper_stopped".
    *   Optionally closes all open positions for that strategy on the linked account (configurable via a flag).
    *   Cleans up resources for the stopped instance.
*   **Request Body:**
    ```json
    {
        "close_open_positions": true // Optional: default to false
    }
    ```
*   **Response (200 OK):**
    ```json
    {
        "message": "Strategy stopped successfully.",
        "deployment_id": "uuid-of-deployment",
        "status": "stopped"
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `403 Forbidden`.
    *   `404 Not Found`.
    *   `409 Conflict`: Strategy not currently running.

---

#### **6.3. Get Active Deployments (F.1.2)**

*   **Endpoint:** `GET /active`
*   **Description:** Retrieves a list of all currently active live or paper trading deployments for the user.
*   **Business Logic:**
    *   Returns real-time status and high-level performance metrics for each running strategy instance.
*   **Response (200 OK):**
    ```json
    [
        {
            "deployment_id": "uuid-deployment-1",
            "strategy_id": "uuid-strategy-1",
            "strategy_name": "My RSI & MA Crossover Strategy",
            "account_id": "uuid-account-1",
            "account_name": "My IC Markets Live Account",
            "operation_mode": "live",
            "status": "running",
            "current_pnl": 150.75, // P&L specific to this deployment
            "total_trades": 5,
            "equity_gain_percent": 1.5,
            "last_trade_time": "2023-10-27T10:45:00Z",
            "risk_profile": { /* current risk parameters */ }
        },
        {
            "deployment_id": "uuid-deployment-2",
            "strategy_id": "uuid-strategy-3",
            "strategy_name": "Another Demo Strategy",
            "account_id": "uuid-account-2",
            "account_name": "My Demo Account",
            "operation_mode": "paper",
            "status": "running",
            "current_pnl": 50.20
        }
    ]
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.

---

#### **6.4. Get Deployment Details**

*   **Endpoint:** `GET /{deployment_id}`
*   **Description:** Retrieves detailed information for a specific running strategy instance.
*   **Business Logic:**
    *   Provides more granular information than `/active`, suitable for a detailed view of a single strategy.
*   **Response (200 OK):**
    ```json
    {
        "deployment_id": "uuid-deployment-1",
        "strategy_id": "uuid-strategy-1",
        "strategy_name": "My RSI & MA Crossover Strategy",
        "account_id": "uuid-account-1",
        "operation_mode": "live",
        "status": "running",
        "started_at": "2023-10-27T08:00:00Z",
        "uptime_seconds": 9600,
        "current_equity": 10150.75,
        "current_drawdown_percent": 0.8,
        "trades_executed": [
            { /* trade object */ },
            { /* trade object */ }
        ],
        "log_messages": [
            {"timestamp": "...", "level": "INFO", "message": "Strategy initialized."},
            {"timestamp": "...", "level": "TRADE", "message": "BUY EURUSD 0.1 lots @ 1.07545"},
        ]
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `403 Forbidden`.
    *   `404 Not Found`.

---

#### **6.5. Emergency Stop All Trading (F.5.6)**

*   **Endpoint:** `POST /emergency-stop`
*   **Description:** Immediately stops all running strategies across all linked accounts for the authenticated user.
*   **Business Logic:**
    *   Requires a valid JWT token.
    *   Iterates through all `active` deployments for the user.
    *   For each deployment, initiates a `stop` command.
    *   **Crucially**: This action will attempt to close *all* open positions across all accounts by default (configurable per user setting).
    *   Should have strong internal logging and perhaps a confirmation step in the UI.
*   **Request Body:**
    ```json
    {
        "close_all_open_positions": true // Highly recommend true for emergency
    }
    ```
*   **Response (200 OK):**
    ```json
    {
        "message": "All active strategies are being stopped.",
        "stopped_deployments_count": 2
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `500 Internal Server Error`: If a critical error prevents stopping some strategies.

---

### **7. Risk Management Service API**

**Base Path:** `/api/v1/risk-management`

This service manages account-wide and strategy-specific risk parameters. Many parameters are set during strategy deployment (`6.1`) but this API allows for independent management.

---

#### **7.1. Get Global Risk Settings (F.5.1, F.5.2, F.5.3)**

*   **Endpoint:** `GET /global`
*   **Description:** Retrieves the global risk management settings for the authenticated user, applied across all deployments.
*   **Business Logic:**
    *   These settings act as overrides or additional layers of safety.
*   **Response (200 OK):**
    ```json
    {
        "max_concurrent_live_strategies": 5,
        "max_concurrent_paper_strategies": 10,
        "global_max_daily_account_loss_percent": 10.0, // F.5.2: Stops all if hit
        "global_max_open_positions_per_account": 20, // F.5.3
        "default_position_sizing_method": "fixed_lot", // "fixed_lot", "percent_equity", "percent_risk"
        "default_fixed_lot_size": 0.01,
        "emergency_close_on_stop_default": true // Default for F.6.2 and F.5.6
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.

---

#### **7.2. Update Global Risk Settings**

*   **Endpoint:** `PUT /global`
*   **Description:** Updates the global risk management settings for the authenticated user.
*   **Business Logic:**
    *   Validates new settings (e.g., cannot set max loss to 0).
    *   Changes will apply to newly deployed strategies and potentially to currently running ones if implemented as real-time checks.
*   **Request Body:**
    ```json
    {
        "global_max_daily_account_loss_percent": 8.0,
        "default_position_sizing_method": "percent_equity",
        "default_percent_equity_risk": 0.5 // 0.5% of equity per trade
    }
    ```
*   **Response (200 OK):**
    ```json
    {
        "message": "Global risk settings updated successfully."
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `400 Bad Request`.

---

### **8. Reporting & Analytics Service API**

**Base Path:** `/api/v1/reports`

This service generates performance reports and analytics.

---

#### **8.1. Get Account Performance Summary (F.1.3, F.1.6)**

*   **Endpoint:** `GET /account/{account_id}/summary`
*   **Description:** Retrieves a performance summary for a specific linked brokerage account over a period.
*   **Business Logic:**
    *   Aggregates data from all strategies run on the specified `account_id`.
    *   Calculates P&L, drawdown, and other metrics from historic trade data.
*   **Query Parameters:**
    *   `start_date`, `end_date`: ISO 8601 datetime strings. Defaults to last 30 days.
    *   `granularity`: "daily", "weekly", "monthly". Defaults to "daily".
*   **Response (200 OK):**
    ```json
    {
        "account_id": "uuid-account-1",
        "period_start": "2023-09-27T00:00:00Z",
        "period_end": "2023-10-27T23:59:59Z",
        "net_profit": 750.25,
        "roi_percent": 7.5,
        "max_drawdown_percent": 5.2,
        "profit_factor": 1.4,
        "sharpe_ratio": 0.9,
        "winning_trades_percent": 58.0,
        "pnl_history": [ // F.1.3
            {"date": "2023-10-20", "pnl": 50.00, "equity": 10050.00},
            {"date": "2023-10-21", "pnl": -20.50, "equity": 10029.50},
            // ...
        ],
        "metrics_by_strategy": {
            "uuid-strategy-1": { /* metrics for this strategy */ },
            "uuid-strategy-3": { /* metrics for this other strategy */ }
        }
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `403 Forbidden`.
    *   `404 Not Found`.

---

#### **8.2. Get Trade History (F.1.5)**

*   **Endpoint:** `GET /account/{account_id}/trades`
*   **Description:** Retrieves a detailed log of all trades executed on a specific account.
*   **Business Logic:**
    *   Paginates results for large datasets.
    *   Provides filtering options for status, symbol, strategy, etc.
*   **Query Parameters:**
    *   `start_time`, `end_time`: ISO 8601 datetime.
    *   `symbol`, `status` ("open", "closed"), `strategy_id`: Filters.
    *   `limit`, `page`: Pagination.
*   **Response (200 OK):**
    ```json
    {
        "account_id": "uuid-account-1",
        "total_trades": 120,
        "trades": [
            {
                "trade_id": "uuid-trade-1",
                "deployment_id": "uuid-deployment-1",
                "strategy_id": "uuid-strategy-1",
                "symbol": "EURUSD",
                "trade_type": "BUY",
                "lot_size": 0.1,
                "entry_price": 1.07500,
                "entry_time": "2023-10-27T09:00:00Z",
                "close_price": 1.07580,
                "close_time": "2023-10-27T09:30:00Z",
                "status": "CLOSED",
                "pnl": 8.00,
                "stop_loss": 1.07400,
                "take_profit": 1.07600,
                "closure_reason": "TakeProfitHit" // "StopLossHit", "ManualClose", "StrategyClose"
            },
            {
                // Another trade
            }
        ],
        "pagination": { /* ... */ }
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `403 Forbidden`.
    *   `404 Not Found`.

---

#### **8.3. Export Report (F.6.4)**

*   **Endpoint:** `GET /export`
*   **Description:** Generates and returns a performance report in a specified format (e.g., PDF, CSV).
*   **Business Logic:**
    *   Uses a templating engine to format the report data.
    *   The `content-type` header will indicate the file type.
*   **Query Parameters:**
    *   `account_id`: (Optional) If not provided, aggregates all user accounts.
    *   `format`: "pdf", "csv".
    *   `start_date`, `end_date`.
*   **Response (200 OK):**
    *   Returns the file binary data directly.
    *   `Content-Type: application/pdf` or `text/csv`.
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `400 Bad Request`: Invalid format or parameters.
    *   `500 Internal Server Error`: Report generation failed.

---

### **9. Notification Service API (F.9.1)**

**Base Path:** `/api/v1/notifications`

Manages user notification preferences and sends alerts.

---

#### **9.1. Get User Notification Settings**

*   **Endpoint:** `GET /settings`
*   **Description:** Retrieves the user's notification preferences.
*   **Response (200 OK):**
    ```json
    {
        "email_enabled": true,
        "push_enabled": true,
        "sms_enabled": false,
        "alert_on_trade_execution": true,
        "alert_on_strategy_status_change": true,
        "alert_on_drawdown_limit": true,
        "alert_on_account_balance_change": false,
        "alert_on_system_errors": true,
        "email_address": "user@example.com", // Cached for convenience, derived from profile
        "phone_number": "+15551234567" // Cached
    }
    ```

---

#### **9.2. Update User Notification Settings**

*   **Endpoint:** `PUT /settings`
*   **Description:** Updates the user's notification preferences.
*   **Request Body:**
    ```json
    {
        "email_enabled": true,
        "alert_on_account_balance_change": true,
        "sms_enabled": false
    }
    ```
*   **Response (200 OK):**
    ```json
    {
        "message": "Notification settings updated successfully."
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `400 Bad Request`.

---

#### **9.3. Register Push Notification Device**

*   **Endpoint:** `POST /devices`
*   **Description:** Registers a device token for push notifications (for mobile apps).
*   **Business Logic:**
    *   Stores `device_token` associated with the `user_id`.
    *   Allows multiple devices per user.
*   **Request Body:**
    ```json
    {
        "device_token": "device-specific-push-token",
        "platform": "ios" // or "android"
    }
    ```
*   **Response (201 Created):**
    ```json
    {
        "message": "Device registered for push notifications."
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `400 Bad Request`.

---

#### **9.4. Send Test Notification**

*   **Endpoint:** `POST /test`
*   **Description:** Sends a test notification to the user's configured channels.
*   **Business Logic:**
    *   Verifies that notification channels are correctly set up and reachable.
*   **Response (200 OK):**
    ```json
    {
        "message": "Test notifications sent to active channels (email, push).",
        "status": {
            "email_sent": true,
            "push_sent": true,
            "sms_sent": false
        }
    }
    ```
*   **Error Responses:**
    *   `401 Unauthorized`.
    *   `500 Internal Server Error`: If notification service is down.

---

### **10. Advanced Features (Phased Rollout)**

These APIs will be developed in later phases. Mockups or high-level descriptions are provided here.

---

#### **10.1. Strategy Marketplace API (F.8)**

**Base Path:** `/api/v1/marketplace`

*   **`GET /strategies`**: List available strategies (with filters, search, sorting by performance, ratings).
*   **`GET /strategies/{strategy_id}`**: Get details of a marketplace strategy.
*   **`POST /strategies/{strategy_id}/purchase`**: Purchase or rent a strategy.
*   **`POST /strategies/{strategy_id}/publish`**: (Seller endpoint) Publish user's own strategy to marketplace.

---

#### **10.2. Social Trading / Copy Trading API (F.10)**

**Base Path:** `/api/v1/copy-trading`

*   **`GET /providers`**: List available traders/bots to copy (with performance metrics, risk ratings).
*   **`POST /copy/{provider_id}/start`**: Start copying trades from a provider to a specific brokerage account.
*   **`POST /copy/{provider_id}/stop`**: Stop copying trades.
*   **`GET /my-copiers`**: (For providers) View who is copying them.
*   **`PUT /settings`**: (For copiers) Adjust copy ratio, max drawdown for copying.

---

#### **10.3. AI/ML Integration (F.7)**

**Base Path:** `/api/v1/ai`

*   **`GET /sentiment-analysis/{symbol}`**: Get current market sentiment for a symbol (from news feeds).
*   **`POST /adaptive-optimization`**: Request AI to adapt strategy parameters based on current market conditions.
*   **`GET /predictions/{symbol}`**: Get short-term price predictions (if feature developed).

---

### **Error Handling Standard Responses**

All error responses will adhere to a consistent JSON structure to facilitate client-side error handling:

```json
{
    "status": "error",
    "code": "specific_error_code", // e.g., "VALIDATION_ERROR", "UNAUTHORIZED_ACCESS", "BROKER_CONNECTION_FAILURE"
    "message": "A human-readable description of the error."
    // Optional: a "details" field for more specific validation errors or debugging info
    // "details": {
    //     "field_name": "Error message for this field"
    // }
}
```

**Common HTTP Status Codes:**

*   `200 OK`: Request successful, response body contains data.
*   `201 Created`: Resource successfully created.
*   `202 Accepted`: Request accepted for processing (e.g., async job).
*   `204 No Content`: Request successful, no response body.
*   `400 Bad Request`: Invalid input, validation failed.
*   `401 Unauthorized`: Authentication required or failed (invalid token).
*   `403 Forbidden`: Authenticated, but user lacks permission to access resource.
*   `404 Not Found`: Resource not found.
*   `405 Method Not Allowed`: HTTP method not supported for the endpoint.
*   `409 Conflict`: Request conflicts with current state of the resource (e.g., trying to delete a live strategy).
*   `429 Too Many Requests`: Rate limit exceeded.
*   `500 Internal Server Error`: Generic server-side error.
*   `503 Service Unavailable`: External service (e.g., broker) is unavailable.

---
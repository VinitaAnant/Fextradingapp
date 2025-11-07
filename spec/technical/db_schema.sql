```sql
-- Database Structure Definition for Forex Trading Bot

-- Table: Users
-- Stores information about individual users of the platform.
CREATE TABLE Users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    registration_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE,
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    user_role ENUM('free', 'premium', 'pro', 'admin') DEFAULT 'free', -- Corresponds to user tiers
    profile_picture_url VARCHAR(255)
);

-- Table: UserSettings
-- Stores user-specific preferences and settings.
CREATE TABLE UserSettings (
    setting_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
    theme VARCHAR(20) DEFAULT 'dark',
    timezone VARCHAR(50) DEFAULT 'UTC',
    notification_preferences JSONB, -- e.g., {'email_alerts': true, 'push_alerts': true, 'sms_alerts': false}
    currency_preference VARCHAR(3) DEFAULT 'USD',
    language VARCHAR(10) DEFAULT 'en',
    CONSTRAINT fk_user_settings FOREIGN KEY (user_id) REFERENCES Users(user_id)
);

-- Table: BrokerAccounts
-- Stores connected brokerage account details for each user.
CREATE TABLE BrokerAccounts (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
    broker_name VARCHAR(50) NOT NULL,
    account_number VARCHAR(100) NOT NULL,
    api_key VARCHAR(255), -- Encrypted API key or OAuth token
    api_secret VARCHAR(255), -- Encrypted API secret
    access_token VARCHAR(255), -- For OAuth based connections
    account_type ENUM('demo', 'live') NOT NULL,
    currency VARCHAR(3) NOT NULL,
    balance DECIMAL(18, 4),
    equity DECIMAL(18, 4),
    is_active BOOLEAN DEFAULT TRUE,
    connected_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_synced TIMESTAMP WITH TIME ZONE,
    CONSTRAINT unique_user_broker_account UNIQUE (user_id, broker_name, account_number)
);

-- Table: Strategies
-- Stores definitions of trading strategies, both pre-built and user-created.
CREATE TABLE Strategies (
    strategy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES Users(user_id) ON DELETE SET NULL, -- NULL for pre-built strategies
    strategy_name VARCHAR(100) NOT NULL,
    description TEXT,
    strategy_type ENUM('visual', 'code', 'pre_built') NOT NULL,
    creation_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_modified_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_public BOOLEAN DEFAULT FALSE, -- For marketplace
    author_id UUID REFERENCES Users(user_id) ON DELETE SET NULL, -- Original author for public strategies
    visual_config JSONB, -- JSON representation of visual builder blocks
    code_script TEXT, -- Actual code for code-based strategies
    parameters JSONB, -- Default or configurable parameters
    version VARCHAR(20) DEFAULT '1.0'
);

-- Table: DeployedStrategies
-- Links strategies to specific brokerage accounts for live or paper trading.
CREATE TABLE DeployedStrategies (
    deployment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_id UUID NOT NULL REFERENCES Strategies(strategy_id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES BrokerAccounts(account_id) ON DELETE CASCADE,
    deployment_name VARCHAR(100) NOT NULL,
    start_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP WITH TIME ZONE,
    status ENUM('running', 'paused', 'stopped', 'error') DEFAULT 'running',
    is_paper_trading BOOLEAN NOT NULL,
    live_parameters JSONB, -- Strategy parameters specific to this deployment
    risk_settings JSONB, -- SL, TP, position sizing specific to this deployment
    performance_metrics JSONB, -- Stored snapshot of performance
    last_update TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table: TradingInstruments
-- Stores information about financial instruments (currency pairs).
CREATE TABLE TradingInstruments (
    instrument_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol VARCHAR(10) UNIQUE NOT NULL, -- e.g., 'EURUSD'
    base_currency VARCHAR(3) NOT NULL, -- e.g., 'EUR'
    quote_currency VARCHAR(3) NOT NULL, -- e.g., 'USD'
    min_trade_size DECIMAL(10, 5),
    max_trade_size DECIMAL(10, 5),
    pip_value DECIMAL(10, 6)
);

-- Table: Trades
-- Logs all executed trades by the bot or manual trades from connected accounts.
CREATE TABLE Trades (
    trade_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    deployment_id UUID REFERENCES DeployedStrategies(deployment_id) ON DELETE SET NULL, -- Which strategy initiated the trade
    -- If manual trade, this will be NULL, but still associated with an account
    account_id UUID NOT NULL REFERENCES BrokerAccounts(account_id) ON DELETE CASCADE,
    instrument_id UUID NOT NULL REFERENCES TradingInstruments(instrument_id),
    broker_trade_id VARCHAR(255), -- Unique ID from the broker
    order_type ENUM('market', 'limit', 'stop') NOT NULL,
    trade_type ENUM('buy', 'sell') NOT NULL,
    volume DECIMAL(18, 8) NOT NULL, -- Lot size
    entry_price DECIMAL(18, 5) NOT NULL,
    exit_price DECIMAL(18, 5),
    open_time TIMESTAMP WITH TIME ZONE NOT NULL,
    close_time TIMESTAMP WITH TIME ZONE,
    stop_loss DECIMAL(18, 5),
    take_profit DECIMAL(18, 5),
    profit_loss DECIMAL(18, 4),
    fees DECIMAL(18, 4),
    status ENUM('open', 'closed', 'cancelled', 'pending') NOT NULL DEFAULT 'pending',
    CONSTRAINT fk_trade_instrument FOREIGN KEY (instrument_id) REFERENCES TradingInstruments(instrument_id)
);

-- Table: HistoricalMarketData
-- Stores aggregated historical market data for backtesting and analysis.
CREATE TABLE HistoricalMarketData (
    data_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instrument_id UUID NOT NULL REFERENCES TradingInstruments(instrument_id),
    timeframe VARCHAR(10) NOT NULL, -- e.g., '1Min', '5Min', '1Hour', '1Day'
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    open_price DECIMAL(18, 5) NOT NULL,
    high_price DECIMAL(18, 5) NOT NULL,
    low_price DECIMAL(18, 5) NOT NULL,
    close_price DECIMAL(18, 5) NOT NULL,
    volume BIGINT,
    provider VARCHAR(50), -- e.g., FXCM, OANDA, custom
    CONSTRAINT unique_historical_data UNIQUE (instrument_id, timeframe, timestamp, provider)
);

-- Table: LiveMarketData
-- Not a persistent table, but conceptually represents the real-time data stream processed by the Market Data Service.
-- Data would be consumed and processed in real-time by the execution engine and other services.

-- Table: BacktestResults
-- Stores the results of backtests performed on strategies.
CREATE TABLE BacktestResults (
    result_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_id UUID NOT NULL REFERENCES Strategies(strategy_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
    instrument_id UUID NOT NULL REFERENCES TradingInstruments(instrument_id),
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    timeframe VARCHAR(10) NOT NULL,
    initial_capital DECIMAL(18, 4) NOT NULL,
    final_capital DECIMAL(18, 4) NOT NULL,
    total_profit LOSS DECIMAL(18, 4) NOT NULL,
    net_profit_percentage DECIMAL(5, 2) NOT NULL,
    drawdown_percentage DECIMAL(5, 2) NOT NULL,
    profit_factor DECIMAL(5, 2),
    winning_rate DECIMAL(5, 2),
    metrics JSONB, -- Additional detailed metrics (Sharpe ratio, max consecutive wins/losses, etc.)
    equity_curve_data JSONB, -- Array of (timestamp, equity) for charting
    trade_log JSONB, -- Summary of trades taken during backtest
    backtest_config JSONB, -- Parameters used for the backtest (spread, slippage, etc.)
    run_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table: OptimizationResults
-- Stores the results from strategy optimization runs.
CREATE TABLE OptimizationResults (
    optimization_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_id UUID NOT NULL REFERENCES Strategies(strategy_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
    instrument_id UUID NOT NULL REFERENCES TradingInstruments(instrument_id),
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    timeframe VARCHAR(10) NOT NULL,
    optimization_method ENUM('brute_force', 'genetic_algorithm', 'walk_forward') NOT NULL,
    optimized_parameters JSONB, -- The best parameter set found
    optimal_metrics JSONB, -- The performance metrics for the best parameter set
    all_runs_summary JSONB, -- Summary of all tested parameter sets (e.g., top 10)
    run_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status ENUM('completed', 'running', 'failed') DEFAULT 'running'
);

-- Table: RiskSettings
-- Stores global and account-specific risk management rules.
CREATE TABLE RiskSettings (
    risk_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
    account_id UUID REFERENCES BrokerAccounts(account_id) ON DELETE CASCADE, -- NULL for global user settings
    max_daily_loss_percentage DECIMAL(5, 2),
    max_drawdown_percentage DECIMAL(5, 2),
    max_open_positions INTEGER,
    default_position_sizing_type ENUM('fixed_lot', 'percent_equity', 'percent_risk') DEFAULT 'percent_equity',
    default_fixed_lot_size DECIMAL(18,8),
    default_risk_percent_per_trade DECIMAL(5,2),
    -- For emergency stop functionality (could be a user setting or a system trigger)
    emergency_stop_enabled BOOLEAN DEFAULT FALSE,
    last_update TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_risk_setting_scope UNIQUE (user_id, account_id)
);

-- Table: Notifications
-- Stores alerts and notifications for users.
CREATE TABLE Notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
    notification_type ENUM('trade_executed', 'strategy_status', 'account_alert', 'system_alert', 'custom') NOT NULL,
    title VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_read BOOLEAN DEFAULT FALSE,
    target_link VARCHAR(255), -- Link to relevant part of the application (e.g., specific trade)
    delivery_method JSONB -- e.g., {'email': true, 'push': true, 'sms': false}
);

-- Table: MarketplaceOfferings
-- For strategies offered in the marketplace.
CREATE TABLE MarketplaceOfferings (
    offering_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_id UUID NOT NULL REFERENCES Strategies(strategy_id) ON DELETE CASCADE,
    seller_id UUID NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
    price DECIMAL(10, 2),
    price_type ENUM('one_time', 'monthly_subscription', 'annually_subscription'),
    description TEXT,
    performance_summary JSONB, -- Snapshot of strategy performance
    listing_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    ratings_average DECIMAL(2, 1),
    review_count INTEGER DEFAULT 0
);

-- Table: MarketplacePurchases
-- Records user purchases of marketplace strategies.
CREATE TABLE MarketplacePurchases (
    purchase_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    offering_id UUID NOT NULL REFERENCES MarketplaceOfferings(offering_id) ON DELETE CASCADE,
    buyer_id UUID NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
    purchase_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    price_paid DECIMAL(10, 2) NOT NULL,
    transaction_id VARCHAR(255), -- Payment gateway transaction ID
    status ENUM('completed', 'failed', 'refunded') DEFAULT 'completed',
    valid_until TIMESTAMP WITH TIME ZONE -- For subscriptions
);

-- Table: StrategyRatings
-- User ratings and reviews for strategies.
CREATE TABLE StrategyRatings (
    rating_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_id UUID NOT NULL REFERENCES Strategies(strategy_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5) NOT NULL,
    review_text TEXT,
    review_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_user_strategy_rating UNIQUE (user_id, strategy_id)
);

-- Table: UserActivityLog
-- General logging of significant user actions for auditing and debugging.
CREATE TABLE UserActivityLog (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES Users(user_id) ON DELETE SET NULL,
    activity_type VARCHAR(50) NOT NULL, -- e.g., 'login', 'strategy_created', 'account_connected', 'trade_executed'
    description TEXT,
    ip_address INET,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB -- Additional contextual information
);

-- Table: SystemLogs
-- For internal system errors, warnings, and informational messages.
CREATE TABLE SystemLogs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_name VARCHAR(50) NOT NULL, -- e.g., 'ExecutionEngine', 'MarketDataService', 'API Gateway'
    log_level ENUM('info', 'warning', 'error', 'debug', 'critical') NOT NULL,
    message TEXT NOT NULL,
    details JSONB, -- Stack trace, error codes, etc.
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_users_email ON Users(email);
CREATE INDEX idx_broker_accounts_user_id ON BrokerAccounts(user_id);
CREATE INDEX idx_strategies_user_id ON Strategies(user_id);
CREATE INDEX idx_deployed_strategies_strategy_id ON DeployedStrategies(strategy_id);
CREATE INDEX idx_deployed_strategies_account_id ON DeployedStrategies(account_id);
CREATE INDEX idx_trades_account_id ON Trades(account_id);
CREATE INDEX idx_trades_deployment_id ON Trades(deployment_id);
CREATE INDEX idx_trades_instrument_id ON Trades(instrument_id);
CREATE INDEX idx_historical_data_instrument_timeframe_timestamp ON HistoricalMarketData(instrument_id, timeframe, timestamp DESC);
CREATE INDEX idx_backtest_results_strategy_id ON BacktestResults(strategy_id);
CREATE INDEX idx_optimization_results_strategy_id ON OptimizationResults(strategy_id);
CREATE INDEX idx_notifications_user_id ON Notifications(user_id);
CREATE INDEX idx_marketplace_offerings_strategy_id ON MarketplaceOfferings(strategy_id);
CREATE INDEX idx_marketplace_purchases_buyer_id ON MarketplacePurchases(buyer_id);
CREATE INDEX idx_strategy_ratings_strategy_id ON StrategyRatings(strategy_id);
CREATE INDEX idx_user_activity_log_user_id ON UserActivityLog(user_id);
CREATE INDEX idx_system_logs_timestamp ON SystemLogs(timestamp);

-- Comments for clarity
COMMENT ON TABLE Users IS 'Stores information about individual users of the platform.';
COMMENT ON TABLE UserSettings IS 'Stores user-specific preferences and settings.';
COMMENT ON TABLE BrokerAccounts IS 'Stores connected brokerage account details for each user.';
COMMENT ON TABLE Strategies IS 'Stores definitions of trading strategies, both pre-built and user-created.';
COMMENT ON TABLE DeployedStrategies IS 'Links strategies to specific brokerage accounts for live or paper trading.';
COMMENT ON TABLE TradingInstruments IS 'Stores information about financial instruments (currency pairs).';
COMMENT ON TABLE Trades IS 'Logs all executed trades by the bot or manual trades from connected accounts.';
COMMENT ON TABLE HistoricalMarketData IS 'Stores aggregated historical market data for backtesting and analysis.';
COMMENT ON TABLE BacktestResults IS 'Stores the results of backtests performed on strategies.';
COMMENT ON TABLE OptimizationResults IS 'Stores the results from strategy optimization runs.';
COMMENT ON TABLE RiskSettings IS 'Stores global and account-specific risk management rules.';
COMMENT ON TABLE Notifications IS 'Stores alerts and notifications for users.';
COMMENT ON TABLE MarketplaceOfferings IS 'For strategies offered in the marketplace.';
COMMENT ON TABLE MarketplacePurchases IS 'Records user purchases of marketplace strategies.';
COMMENT ON TABLE StrategyRatings IS 'User ratings and reviews for strategies.';
COMMENT ON TABLE UserActivityLog IS 'General logging of significant user actions for auditing and debugging.';
COMMENT ON TABLE SystemLogs IS 'For internal system errors, warnings, and informational messages.';
```
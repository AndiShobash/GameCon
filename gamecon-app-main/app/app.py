import os
import logging
import time
import json
import uuid
from flask import Flask, request, g
from config import Config
from models import db
from routes import bp
from prometheus_flask_exporter import PrometheusMetrics
from prometheus_client import Counter, Histogram, Gauge

class JSONFormatter(logging.Formatter):
    """Custom JSON formatter for structured logging"""
    
    def format(self, record):
        log_entry = {
            'timestamp': self.formatTime(record, self.datetimeformat),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'module': record.module,
            'function': record.funcName,
            'line': record.lineno,
        }
        
        # Add request context if available
        if hasattr(g, 'request_id'):
            log_entry['request_id'] = g.request_id
            
        if request:
            try:
                log_entry.update({
                    'http_method': request.method,
                    'http_url': request.url,
                    'http_path': request.path,
                    'http_query_string': request.query_string.decode('utf-8'),
                    'http_user_agent': request.headers.get('User-Agent', ''),
                    'http_remote_addr': request.remote_addr,
                    'http_referrer': request.headers.get('Referer', ''),
                })
            except RuntimeError:
                # Outside of request context
                pass
        
        # Add exception info if present
        if record.exc_info:
            log_entry['exception'] = self.formatException(record.exc_info)
            
        # Add extra fields
        if hasattr(record, 'extra_fields'):
            log_entry.update(record.extra_fields)
            
        return json.dumps(log_entry, ensure_ascii=False)

def setup_logging():
    """Setup structured logging for Kibana"""
    log_level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
    log_level = getattr(logging, log_level_str, logging.INFO)
    
    # Clear existing handlers
    logging.getLogger().handlers.clear()
    
    # Create handler
    handler = logging.StreamHandler()
    
    # Use JSON formatter for production, simple for development
    if os.environ.get('ENVIRONMENT') == 'production':
        formatter = JSONFormatter()
    else:
        formatter = logging.Formatter(
            '%(asctime)s [%(levelname)s] %(name)s: %(message)s'
        )
    
    handler.setFormatter(formatter)
    
    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)
    root_logger.addHandler(handler)
    
    # Configure Flask app logger
    app_logger = logging.getLogger(__name__)
    app_logger.info("Logging configured", extra={
        'extra_fields': {
            'log_level': log_level_str,
            'environment': os.environ.get('ENVIRONMENT', 'development'),
            'app_name': 'gamecon'
        }
    })
    
    return app_logger

def get_app_games_summary():
    """Get summary of games in the app for logging context"""
    try:
        from models import Game
        games = Game.query.with_entities(Game.id, Game.title, Game.genre, Game.platform).all()
        
        summary = {
            'total_games': len(games),
            'game_names': [game.title for game in games],
            'genres': list(set([game.genre for game in games])) if games else [],
            'platforms': list(set([game.platform for game in games])) if games else [],
            'games_detail': [
                {
                    'id': game.id, 
                    'title': game.title, 
                    'genre': game.genre, 
                    'platform': game.platform
                } for game in games
            ]
        }
        return summary
    except Exception as e:
        return {
            'total_games': 0,
            'game_names': [],
            'genres': [],
            'platforms': [],
            'games_detail': [],
            'error': f"Could not retrieve games: {str(e)}"
        }

def create_app():
    app = Flask(__name__, 
                template_folder='../templates', 
                static_folder='../static')
    app.config.from_object(Config)

    # Setup logging
    logger = setup_logging()

    db.init_app(app)
    
    # Create tables automatically instead of using migrations
    with app.app_context():
        db.create_all()
        
        # Get initial games summary for startup logging
        games_summary = get_app_games_summary()
        
        logger.info("Database tables created/verified", extra={
            'extra_fields': {
                'database_url': app.config['SQLALCHEMY_DATABASE_URI'].split('@')[1] if '@' in app.config['SQLALCHEMY_DATABASE_URI'] else 'local',
                'operation': 'database_init',
                'games_at_startup': games_summary
            }
        })
    
    # Initialize Prometheus metrics only if not testing
    if not app.config.get('TESTING', False):
        # Initialize prometheus_flask_exporter
        metrics = PrometheusMetrics(app)
        
        # Add custom application info
        try:
            metrics.info('gamecon_app_info', 'GameCon Application info', version='1.0.0')
        except ValueError:
            pass  # Metric already exists
        
        # Custom metrics for GameCon operations
        app.game_operations_counter = Counter(
            'gamecon_game_operations_total',
            'Total game operations',
            ['operation', 'status']
        )
        
        app.active_games_gauge = Gauge(
            'gamecon_active_games_total',
            'Total number of active games in database'
        )
        
        app.request_duration_histogram = Histogram(
            'gamecon_request_duration_seconds',
            'Time spent processing requests',
            ['method', 'endpoint', 'status']
        )

    import base64
    @app.template_filter('b64encode')
    def b64encode_filter(data):
        return base64.b64encode(data).decode('utf-8')

    app.register_blueprint(bp)

    # Template filter for static URL with CloudFront support
    @app.template_filter('static_url')
    def static_url_filter(filename):
        """Generate static URL using CloudFront if configured"""
        cdn_domain = app.config.get('CDN_DOMAIN')
        if cdn_domain:
            return f"https://{cdn_domain}/static/{filename}"
        return f"/static/{filename}"

    # Context processor to make static_url available in templates
    @app.context_processor
    def inject_static_url():
        return dict(static_url=lambda filename: static_url_filter(filename))

    # BEFORE REQUEST
    @app.before_request
    def before_request():
        # Generate unique request ID for tracing
        g.request_id = str(uuid.uuid4())
        g.start_time = time.time()
        
        if not app.config.get('TESTING', False):
            # Get current games context for request logging
            with app.app_context():
                games_context = get_app_games_summary()
            
            logger.info("Request started", extra={
                'extra_fields': {
                    'request_id': g.request_id,
                    'operation': 'request_start',
                    'endpoint': request.endpoint,
                    'content_length': request.content_length or 0,
                    'content_type': request.content_type or '',
                    'current_app_state': {
                        'total_games': games_context['total_games'],
                        'game_names': games_context['game_names'][:5],  # First 5 names to avoid too much data
                        'has_more_games': games_context['total_games'] > 5
                    }
                }
            })

    # AFTER REQUEST
    @app.after_request
    def after_request(response):
        if not app.config.get('TESTING', False):
            duration = time.time() - g.start_time if hasattr(g, 'start_time') else 0
            
            # Get current games context for response logging
            games_context = get_app_games_summary()
            
            logger.info("Request completed", extra={
                'extra_fields': {
                    'request_id': g.request_id if hasattr(g, 'request_id') else 'unknown',
                    'operation': 'request_end',
                    'status_code': response.status_code,
                    'response_size': len(response.get_data()) if response.get_data() else 0,
                    'duration_ms': round(duration * 1000, 2),
                    'endpoint': request.endpoint or 'unknown',
                    'app_state_after_request': {
                        'total_games': games_context['total_games'],
                        'game_names': games_context['game_names'],
                        'unique_genres': games_context['genres'],
                        'unique_platforms': games_context['platforms']
                    }
                }
            })
            
            # Log slow requests
            if duration > 1.0:  # More than 1 second
                logger.warning("Slow request detected", extra={
                    'extra_fields': {
                        'request_id': g.request_id if hasattr(g, 'request_id') else 'unknown',
                        'operation': 'slow_request',
                        'duration_ms': round(duration * 1000, 2),
                        'endpoint': request.endpoint or 'unknown',
                        'slow_request_threshold': 1000,
                        'app_context_during_slow_request': {
                            'total_games': games_context['total_games'],
                            'game_names': games_context['game_names']
                        }
                    }
                })
            
            # Record custom metrics
            if hasattr(app, 'game_operations_counter') and request.path.startswith('/games'):
                operation = 'unknown'
                if request.method == 'GET':
                    if '/games/new' in request.path:
                        operation = 'new_form'
                    elif '/edit' in request.path:
                        operation = 'edit_form'
                    elif request.path == '/':
                        operation = 'list'
                    else:
                        operation = 'view'
                elif request.method == 'POST':
                    if '/games/new' in request.path:
                        operation = 'create'
                    elif '/edit' in request.path:
                        operation = 'update'
                    elif '/delete' in request.path:
                        operation = 'delete'
                
                app.game_operations_counter.labels(
                    operation=operation,
                    status=response.status_code
                ).inc()
                
                # Enhanced game operations logging with current app state
                logger.info("Game operation completed", extra={
                    'extra_fields': {
                        'request_id': g.request_id if hasattr(g, 'request_id') else 'unknown',
                        'operation': f'game_{operation}',
                        'game_operation_type': operation,
                        'status_code': response.status_code,
                        'success': response.status_code < 400,
                        'app_state_during_operation': {
                            'total_games': games_context['total_games'],
                            'all_game_names': games_context['game_names'],
                            'genres_in_app': games_context['genres'],
                            'platforms_in_app': games_context['platforms'],
                            'operation_impact': f"{operation} operation on app with {games_context['total_games']} games"
                        }
                    }
                })
            
            # Update active games count
            if hasattr(app, 'active_games_gauge'):
                try:
                    app.active_games_gauge.set(games_context['total_games'])
                    
                    # Log metrics update with game context
                    logger.debug("Metrics updated", extra={
                        'extra_fields': {
                            'request_id': g.request_id if hasattr(g, 'request_id') else 'unknown',
                            'operation': 'metrics_update',
                            'games_count_metric': games_context['total_games'],
                            'current_games': games_context['game_names']
                        }
                    })
                    
                except Exception as e:
                    logger.error("Error updating games count", extra={
                        'extra_fields': {
                            'request_id': g.request_id if hasattr(g, 'request_id') else 'unknown',
                            'operation': 'metrics_update_error',
                            'error_type': type(e).__name__,
                            'error_message': str(e),
                            'attempted_games_count': games_context['total_games']
                        }
                    })
            
            # Record request duration
            if hasattr(app, 'request_duration_histogram'):
                endpoint = request.endpoint or 'unknown'
                app.request_duration_histogram.labels(
                    method=request.method,
                    endpoint=endpoint,
                    status=response.status_code
                ).observe(duration)
        
        return response
    
    # Error handlers with structured logging including game context
    @app.errorhandler(404)
    def not_found_error(error):
        games_context = get_app_games_summary()
        
        logger.warning("Page not found", extra={
            'extra_fields': {
                'request_id': g.request_id if hasattr(g, 'request_id') else 'unknown',
                'operation': 'http_404',
                'requested_path': request.path,
                'error_type': '404_not_found',
                'app_state_during_404': {
                    'total_games': games_context['total_games'],
                    'available_games': games_context['game_names']
                }
            }
        })
        return "Page not found", 404
    
    @app.errorhandler(500)
    def internal_error(error):
        games_context = get_app_games_summary()
        
        logger.error("Internal server error", extra={
            'extra_fields': {
                'request_id': g.request_id if hasattr(g, 'request_id') else 'unknown',
                'operation': 'http_500',
                'error_type': '500_internal_error',
                'error_message': str(error),
                'app_state_during_error': {
                    'total_games': games_context['total_games'],
                    'games_in_app': games_context['game_names']
                }
            }
        })
        return "Internal server error", 500

    # Add a periodic logging task to show current app state
    @app.cli.command()
    def log_app_state():
        """CLI command to log current application state"""
        with app.app_context():
            games_summary = get_app_games_summary()
            logger.info("Current application state", extra={
                'extra_fields': {
                    'operation': 'app_state_summary',
                    'timestamp': time.time(),
                    'detailed_app_state': games_summary,
                    'summary': f"GameCon app running with {games_summary['total_games']} games: {', '.join(games_summary['game_names']) if games_summary['game_names'] else 'No games yet'}"
                }
            })

    return app

if __name__ == "__main__":
    app = create_app()
    
    # Log startup state
    with app.app_context():
        startup_games = get_app_games_summary()
        logger = logging.getLogger(__name__)
        logger.info("GameCon application starting", extra={
            'extra_fields': {
                'operation': 'app_startup',
                'startup_games_state': startup_games,
                'environment': os.environ.get('ENVIRONMENT', 'development'),
                'debug_mode': True,
                'startup_summary': f"Starting with {startup_games['total_games']} games in database"
            }
        })
    
    app.run(host='0.0.0.0', port=5000, debug=True, use_reloader=False)
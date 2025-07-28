import os
import requests
import logging
from flask import Blueprint, render_template, request, jsonify, current_app, redirect, url_for, g
from werkzeug.utils import secure_filename
from models import db, Game
from prometheus_flask_exporter import PrometheusMetrics
from sqlalchemy import text

bp = Blueprint('routes', __name__)
logger = logging.getLogger(__name__)

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in current_app.config['ALLOWED_EXTENSIONS']

def get_current_game_names():
    """Get list of current game names for logging context"""
    try:
        games = Game.query.with_entities(Game.id, Game.title).all()
        return [{'id': game.id, 'title': game.title} for game in games]
    except Exception as e:
        logger.warning("Could not retrieve game names for logging", extra={
            'extra_fields': {
                'operation': 'get_game_names_error',
                'error_type': type(e).__name__,
                'error_message': str(e)
            }
        })
        return []

def download_image_from_url(image_url):
    """Download image from URL or process data URL and return image data and mime type"""
    request_id = getattr(g, 'request_id', 'unknown')
    
    try:
        logger.info("Starting image download", extra={
            'extra_fields': {
                'request_id': request_id,
                'operation': 'image_download_start',
                'image_url_type': 'data_url' if image_url.startswith('data:') else 'http_url',
                'url_length': len(image_url)
            }
        })
        
        # Check if it's a data URL
        if image_url.startswith('data:'):
            # Parse data URL: data:image/jpeg;base64,/9j/4AAQSkZJRg...
            try:
                import base64
                # Split the data URL
                header, data = image_url.split(',', 1)
                # Extract mime type from header (data:image/jpeg;base64)
                mime_type = header.split(':')[1].split(';')[0]
                # Decode the base64 data
                image_data = base64.b64decode(data)
                
                logger.info("Data URL processed successfully", extra={
                    'extra_fields': {
                        'request_id': request_id,
                        'operation': 'data_url_processed',
                        'mime_type': mime_type,
                        'image_size_bytes': len(image_data)
                    }
                })
                
                return image_data, mime_type
            except Exception as e:
                logger.error("Error processing data URL", extra={
                    'extra_fields': {
                        'request_id': request_id,
                        'operation': 'data_url_error',
                        'error_type': type(e).__name__,
                        'error_message': str(e)
                    }
                })
                return None, None
        else:
            # Regular HTTP URL - download the image
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
            
            logger.info("Downloading image from HTTP URL", extra={
                'extra_fields': {
                    'request_id': request_id,
                    'operation': 'http_image_download',
                    'url_domain': image_url.split('/')[2] if len(image_url.split('/')) > 2 else 'unknown'
                }
            })
            
            response = requests.get(image_url, timeout=10, headers=headers)
            response.raise_for_status()
            
            # Check if the response is an image
            content_type = response.headers.get('content-type', '')
            if not content_type.startswith('image/'):
                logger.warning("Downloaded content is not an image", extra={
                    'extra_fields': {
                        'request_id': request_id,
                        'operation': 'invalid_image_content',
                        'content_type': content_type,
                        'response_size': len(response.content)
                    }
                })
                return None, None
            
            logger.info("Image downloaded successfully", extra={
                'extra_fields': {
                    'request_id': request_id,
                    'operation': 'http_image_downloaded',
                    'content_type': content_type,
                    'image_size_bytes': len(response.content),
                    'response_status': response.status_code
                }
            })
                
            return response.content, content_type
            
    except requests.RequestException as e:
        logger.error("HTTP request error during image download", extra={
            'extra_fields': {
                'request_id': request_id,
                'operation': 'image_download_http_error',
                'error_type': type(e).__name__,
                'error_message': str(e),
                'url_domain': image_url.split('/')[2] if len(image_url.split('/')) > 2 else 'unknown'
            }
        })
        return None, None
    except Exception as e:
        logger.error("Unexpected error during image download", extra={
            'extra_fields': {
                'request_id': request_id,
                'operation': 'image_download_error',
                'error_type': type(e).__name__,
                'error_message': str(e)
            }
        })
        return None, None

@bp.route("/", methods=["GET"])
def home():
    request_id = getattr(g, 'request_id', 'unknown')
    
    try:
        games = Game.query.order_by(Game.title.asc()).all()
        game_names = [game.title for game in games]
        
        logger.info("Home page loaded", extra={
            'extra_fields': {
                'request_id': request_id,
                'operation': 'home_page_load',
                'games_count': len(games),
                'current_game_names': game_names,
                'games_summary': f"Games in app: {', '.join(game_names[:5])}" + (f" and {len(game_names) - 5} more" if len(game_names) > 5 else "")
            }
        })
        
        return render_template("index.html", games=games)
    except Exception as e:
        logger.error("Error loading home page", extra={
            'extra_fields': {
                'request_id': request_id,
                'operation': 'home_page_error',
                'error_type': type(e).__name__,
                'error_message': str(e)
            }
        })
        raise

@bp.route("/games/new", methods=["GET", "POST"])
def new_game():
    request_id = getattr(g, 'request_id', 'unknown')
    
    if request.method == "POST":
        title = request.form.get("title")
        genre = request.form.get("genre")
        platform = request.form.get("platform")
        image_url = request.form.get("image_url")
        
        # Get current games for context
        current_games = get_current_game_names()
        
        logger.info("Creating new game", extra={
            'extra_fields': {
                'request_id': request_id,
                'operation': 'game_creation_start',
                'game_title': title,
                'game_genre': genre,
                'game_platform': platform,
                'has_image_url': bool(image_url and image_url.strip()),
                'current_games_count': len(current_games),
                'existing_game_names': [game['title'] for game in current_games],
                'is_duplicate_name': title in [game['title'] for game in current_games] if title else False
            }
        })
        
        image_data = None
        image_mime = None
        
        # If URL is provided, download the image
        if image_url and image_url.strip():
            image_data, image_mime = download_image_from_url(image_url.strip())
            if not image_data:
                logger.warning("Game creation failed due to image download error", extra={
                    'extra_fields': {
                        'request_id': request_id,
                        'operation': 'game_creation_failed',
                        'failure_reason': 'image_download_failed',
                        'game_title': title,
                        'current_games_count': len(current_games)
                    }
                })
                return render_template("create_game.html", error="Could not download image from URL. Please check the URL and try again.")

        try:
            new_game = Game(
                title=title,
                genre=genre,
                platform=platform,
                image_data=image_data,
                image_mime=image_mime
            )
            db.session.add(new_game)
            db.session.commit()
            
            # Get updated game list for logging
            updated_games = get_current_game_names()
            
            logger.info("Game created successfully", extra={
                'extra_fields': {
                    'request_id': request_id,
                    'operation': 'game_created',
                    'game_id': new_game.id,
                    'game_title': title,
                    'has_image': bool(image_data),
                    'total_games_after_creation': len(updated_games),
                    'all_game_names_after_creation': [game['title'] for game in updated_games],
                    'newly_added_game': {'id': new_game.id, 'title': title, 'genre': genre, 'platform': platform}
                }
            })
            
            return redirect(url_for('routes.home'))
            
        except Exception as e:
            db.session.rollback()
            logger.error("Database error during game creation", extra={
                'extra_fields': {
                    'request_id': request_id,
                    'operation': 'game_creation_db_error',
                    'error_type': type(e).__name__,
                    'error_message': str(e),
                    'game_title': title,
                    'current_games_count': len(current_games)
                }
            })
            return render_template("create_game.html", error="Error creating game. Please try again.")
    else:
        # GET request - show form
        current_games = get_current_game_names()
        logger.info("New game form accessed", extra={
            'extra_fields': {
                'request_id': request_id,
                'operation': 'new_game_form_load',
                'current_games_count': len(current_games),
                'existing_game_names': [game['title'] for game in current_games]
            }
        })
    
    return render_template("create_game.html")

@bp.route("/games/<int:id>", methods=["GET"])
def show_game(id):
    request_id = getattr(g, 'request_id', 'unknown')
    
    try:
        game = Game.query.get_or_404(id)
        current_games = get_current_game_names()
        
        logger.info("Game details viewed", extra={
            'extra_fields': {
                'request_id': request_id,
                'operation': 'game_view',
                'game_id': id,
                'game_title': game.title,
                'game_genre': game.genre,
                'game_platform': game.platform,
                'total_games_in_app': len(current_games),
                'all_game_names': [g['title'] for g in current_games],
                'viewed_game_context': f"Viewing '{game.title}' out of {len(current_games)} total games"
            }
        })
        
        return render_template("game_detail.html", game=game)
    except Exception as e:
        logger.error("Error viewing game details", extra={
            'extra_fields': {
                'request_id': request_id,
                'operation': 'game_view_error',
                'game_id': id,
                'error_type': type(e).__name__,
                'error_message': str(e)
            }
        })
        raise

@bp.route("/games/<int:id>/edit", methods=["GET", "POST"])
def edit_game(id):
    request_id = getattr(g, 'request_id', 'unknown')
    
    try:
        game = Game.query.get_or_404(id)
        current_games = get_current_game_names()
        
        if request.method == "POST":
            old_title = game.title
            old_genre = game.genre
            old_platform = game.platform
            
            game.title = request.form.get("title")
            game.genre = request.form.get("genre")
            game.platform = request.form.get("platform")

            logger.info("Updating game", extra={
                'extra_fields': {
                    'request_id': request_id,
                    'operation': 'game_update_start',
                    'game_id': id,
                    'old_title': old_title,
                    'new_title': game.title,
                    'old_genre': old_genre,
                    'new_genre': game.genre,
                    'old_platform': old_platform,
                    'new_platform': game.platform,
                    'title_changed': old_title != game.title,
                    'genre_changed': old_genre != game.genre,
                    'platform_changed': old_platform != game.platform,
                    'total_games_in_app': len(current_games),
                    'other_game_names': [g['title'] for g in current_games if g['id'] != id]
                }
            })

            # Handle URL-based image update
            image_url = request.form.get("image_url")
            if image_url and image_url.strip():
                image_data, image_mime = download_image_from_url(image_url.strip())
                if image_data:
                    game.image_data = image_data
                    game.image_mime = image_mime

            db.session.commit()
            
            # Get updated game list
            updated_games = get_current_game_names()
            
            logger.info("Game updated successfully", extra={
                'extra_fields': {
                    'request_id': request_id,
                    'operation': 'game_updated',
                    'game_id': id,
                    'game_title': game.title,
                    'changes_made': {
                        'title': {'from': old_title, 'to': game.title} if old_title != game.title else None,
                        'genre': {'from': old_genre, 'to': game.genre} if old_genre != game.genre else None,
                        'platform': {'from': old_platform, 'to': game.platform} if old_platform != game.platform else None
                    },
                    'all_game_names_after_update': [g['title'] for g in updated_games]
                }
            })
            
            return redirect(url_for('routes.show_game', id=game.id))
        else:
            # GET request - show edit form
            logger.info("Edit game form accessed", extra={
                'extra_fields': {
                    'request_id': request_id,
                    'operation': 'edit_game_form_load',
                    'game_id': id,
                    'game_title': game.title,
                    'total_games_in_app': len(current_games),
                    'other_game_names': [g['title'] for g in current_games if g['id'] != id]
                }
            })

        return render_template("edit_game.html", game=game)
        
    except Exception as e:
        logger.error("Error during game edit", extra={
            'extra_fields': {
                'request_id': request_id,
                'operation': 'game_edit_error',
                'game_id': id,
                'error_type': type(e).__name__,
                'error_message': str(e)
            }
        })
        raise

@bp.route("/games/<int:id>/delete", methods=["POST"])
def delete_game_web(id):
    request_id = getattr(g, 'request_id', 'unknown')
    
    try:
        game = Game.query.get_or_404(id)
        game_title = game.title
        game_genre = game.genre
        game_platform = game.platform
        
        # Get current games before deletion
        current_games = get_current_game_names()
        games_before_deletion = [g['title'] for g in current_games]
        
        logger.info("Deleting game", extra={
            'extra_fields': {
                'request_id': request_id,
                'operation': 'game_deletion_start',
                'game_id': id,
                'game_title': game_title,
                'game_genre': game_genre,
                'game_platform': game_platform,
                'total_games_before_deletion': len(current_games),
                'all_games_before_deletion': games_before_deletion,
                'remaining_games_after_deletion_preview': [g for g in games_before_deletion if g != game_title]
            }
        })
        
        db.session.delete(game)
        db.session.commit()
        
        # Get updated game list after deletion
        remaining_games = get_current_game_names()
        
        logger.info("Game deleted successfully", extra={
            'extra_fields': {
                'request_id': request_id,
                'operation': 'game_deleted',
                'game_id': id,
                'deleted_game_title': game_title,
                'deleted_game_genre': game_genre,
                'deleted_game_platform': game_platform,
                'total_games_after_deletion': len(remaining_games),
                'remaining_game_names': [g['title'] for g in remaining_games],
                'games_count_change': len(current_games) - len(remaining_games)
            }
        })
        
        return redirect(url_for('routes.home'))
        
    except Exception as e:
        db.session.rollback()
        logger.error("Error during game deletion", extra={
            'extra_fields': {
                'request_id': request_id,
                'operation': 'game_deletion_error',
                'game_id': id,
                'error_type': type(e).__name__,
                'error_message': str(e)
            }
        })
        raise

@bp.route("/health", methods=["GET"])
def health_check():
    request_id = getattr(g, 'request_id', 'unknown')
    
    try:
        db.session.execute(text('SELECT 1'))
        
        # Include game count and names in health check
        current_games = get_current_game_names()
        
        logger.info("Health check passed", extra={
            'extra_fields': {
                'request_id': request_id,
                'operation': 'health_check_success',
                'database_status': 'connected',
                'total_games': len(current_games),
                'game_names': [g['title'] for g in current_games]
            }
        })
        
        return jsonify({
            "status": "ok", 
            "games_count": len(current_games),
            "games": [g['title'] for g in current_games]
        }), 200
    except Exception as e:
        logger.error("Health check failed", extra={
            'extra_fields': {
                'request_id': request_id,
                'operation': 'health_check_failed',
                'database_status': 'error',
                'error_type': type(e).__name__,
                'error_message': str(e)
            }
        })
        return jsonify({"status": "error", "message": str(e)}), 500

@bp.route("/metrics")
def metrics():
    """Expose metrics endpoint"""
    # This is automatically handled by prometheus_flask_exporter
    # but we're making it explicit here  
    pass
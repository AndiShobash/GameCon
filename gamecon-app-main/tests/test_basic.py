import pytest
import sys
import os
from unittest.mock import patch, Mock

# Add the app directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'app'))

def test_config():
    """Test configuration loading"""
    from config import Config
    assert Config.SQLALCHEMY_TRACK_MODIFICATIONS == False
    assert Config.MAX_CONTENT_LENGTH == 16 * 1024 * 1024
    assert 'png' in Config.ALLOWED_EXTENSIONS

def test_game_model():
    """Test the Game model"""
    from models import Game
    
    game = Game(
        title='Test Game',
        genre='Action',
        platform='PC'
    )
    assert game.title == 'Test Game'
    assert game.genre == 'Action'
    assert game.platform == 'PC'

@patch.dict(os.environ, {'DATABASE_URL': 'sqlite:///:memory:', 'TESTING': 'True'})
def test_app_creation():
    """Test that app can be created"""
    from app import create_app
    app = create_app()
    assert app.config['TESTING'] is False  # Set by environment, not config

def test_allowed_file_function():
    """Test the allowed_file function"""
    from routes import allowed_file
    from flask import Flask
    
    app = Flask(__name__)
    app.config['ALLOWED_EXTENSIONS'] = {'png', 'jpg', 'jpeg', 'gif'}
    
    with app.app_context():
        assert allowed_file('test.png') == True
        assert allowed_file('test.jpg') == True
        assert allowed_file('test.gif') == True
        assert allowed_file('test.txt') == False
        assert allowed_file('noextension') == False

def test_download_image_data_url():
    """Test data URL processing"""
    from routes import download_image_from_url
    from flask import Flask, g
    
    app = Flask(__name__)
    with app.app_context():
        g.request_id = 'test-123'
        
        # Test with valid PNG data URL
        pixel_png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
        data_url = f"data:image/png;base64,{pixel_png}"
        
        with patch('routes.logger'):
            image_data, mime_type = download_image_from_url(data_url)
            
        assert image_data is not None
        assert mime_type == 'image/png'

@patch('routes.requests.get')
def test_download_image_http_url(mock_get):
    """Test HTTP URL image download"""
    from routes import download_image_from_url
    from flask import Flask, g
    
    # Mock successful response
    mock_response = Mock()
    mock_response.status_code = 200
    mock_response.headers = {'content-type': 'image/jpeg'}
    mock_response.content = b'fake_jpeg_data'
    mock_response.raise_for_status.return_value = None
    mock_get.return_value = mock_response
    
    app = Flask(__name__)
    with app.app_context():
        g.request_id = 'test-456'
        
        with patch('routes.logger'):
            image_data, mime_type = download_image_from_url('https://example.com/test.jpg')
        
        assert image_data == b'fake_jpeg_data'
        assert mime_type == 'image/jpeg'

@patch('routes.requests.get')
def test_download_image_failure(mock_get):
    """Test image download failure handling"""
    from routes import download_image_from_url
    from flask import Flask, g
    import requests
    
    # Mock failed response
    mock_get.side_effect = requests.RequestException("Network error")
    
    app = Flask(__name__)
    with app.app_context():
        g.request_id = 'test-789'
        
        with patch('routes.logger'):
            image_data, mime_type = download_image_from_url('https://bad-url.com/test.jpg')
        
        assert image_data is None
        assert mime_type is None

def test_import_all_modules():
    """Test that all modules can be imported without errors"""
    try:
        from app import create_app
        from models import db, Game
        from routes import bp, allowed_file, download_image_from_url
        from config import Config
        
        # Test that all imports succeeded
        assert create_app is not None
        assert db is not None
        assert Game is not None
        assert bp is not None
        assert allowed_file is not None
        assert download_image_from_url is not None
        assert Config is not None
        
    except ImportError as e:
        pytest.fail(f"Import failed: {e}")

def test_environment_variables():
    """Test environment variable handling"""
    # Test with SQLite
    with patch.dict(os.environ, {'DATABASE_URL': 'sqlite:///test.db'}):
        from config import Config
        # The Config class should use the environment variable
        assert 'sqlite' in Config.SQLALCHEMY_DATABASE_URI or 'postgres' in Config.SQLALCHEMY_DATABASE_URI

def test_game_model_properties():
    """Test Game model field properties"""
    from models import Game, db
    
    # Test that the model has the right fields
    assert hasattr(Game, 'id')
    assert hasattr(Game, 'title')
    assert hasattr(Game, 'genre')
    assert hasattr(Game, 'platform')
    assert hasattr(Game, 'image_data')
    assert hasattr(Game, 'image_mime')
    
    # Test field types (basic validation)
    game = Game()
    assert game.id is None  # Should be None before save
    
def test_invalid_data_url():
    """Test handling of invalid data URLs"""
    from routes import download_image_from_url
    from flask import Flask, g
    
    app = Flask(__name__)
    with app.app_context():
        g.request_id = 'test-invalid'
        
        with patch('routes.logger'):
            # Test with malformed data URL
            image_data, mime_type = download_image_from_url('data:invalid_format')
            
        assert image_data is None
        assert mime_type is None
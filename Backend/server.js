const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static('uploads'));

// Create uploads directory if it doesn't exist
if (!fs.existsSync('uploads')) {
  fs.mkdirSync('uploads');
}

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|gif/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'));
    }
  }
});

// In-memory database (replace with MongoDB or PostgreSQL in production)
let activities = [];
let idCounter = 1;

// Routes

// Health check
app.get('/', (req, res) => {
  res.json({
    message: 'SmartTracker API is running',
    version: '1.0.0',
    endpoints: {
      'GET /api/activities': 'Get all activities',
      'POST /api/activities': 'Create new activity',
      'GET /api/activities/:id': 'Get activity by ID',
      'DELETE /api/activities/:id': 'Delete activity'
    }
  });
});

// Get all activities
app.get('/api/activities', (req, res) => {
  try {
    // Sort by timestamp (newest first)
    const sortedActivities = activities.sort((a, b) =>
      new Date(b.timestamp) - new Date(a.timestamp)
    );

    res.json(sortedActivities);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch activities' });
  }
});

// Get single activity
app.get('/api/activities/:id', (req, res) => {
  try {
    const activity = activities.find(a => a.id === req.params.id);

    if (!activity) {
      return res.status(404).json({ error: 'Activity not found' });
    }

    res.json(activity);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch activity' });
  }
});

// Create new activity
app.post('/api/activities', upload.single('image'), (req, res) => {
  try {
    const { latitude, longitude, description, timestamp } = req.body;

    // Validation
    if (!latitude || !longitude) {
      return res.status(400).json({ error: 'Latitude and longitude are required' });
    }

    const activity = {
      id: String(idCounter++),
      latitude: parseFloat(latitude),
      longitude: parseFloat(longitude),
      description: description || null,
      timestamp: timestamp || new Date().toISOString(),
      imageUrl: req.file ? `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}` : null,
      imagePath: req.file ? req.file.path : null
    };

    activities.push(activity);

    res.status(201).json(activity);
  } catch (error) {
    console.error('Error creating activity:', error);
    res.status(500).json({ error: 'Failed to create activity' });
  }
});

// Update activity
app.put('/api/activities/:id', upload.single('image'), (req, res) => {
  try {
    const { latitude, longitude, description } = req.body;
    const activityIndex = activities.findIndex(a => a.id === req.params.id);

    if (activityIndex === -1) {
      return res.status(404).json({ error: 'Activity not found' });
    }

    const activity = activities[activityIndex];

    // Update fields
    if (latitude) activity.latitude = parseFloat(latitude);
    if (longitude) activity.longitude = parseFloat(longitude);
    if (description) activity.description = description;

    // Update image if provided
    if (req.file) {
      // Delete old image
      if (activity.imagePath && fs.existsSync(activity.imagePath)) {
        fs.unlinkSync(activity.imagePath);
      }

      activity.imageUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
      activity.imagePath = req.file.path;
    }

    activities[activityIndex] = activity;

    res.json(activity);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update activity' });
  }
});

// Delete activity
app.delete('/api/activities/:id', (req, res) => {
  try {
    const activityIndex = activities.findIndex(a => a.id === req.params.id);

    if (activityIndex === -1) {
      return res.status(404).json({ error: 'Activity not found' });
    }

    const activity = activities[activityIndex];

    // Delete associated image file
    if (activity.imagePath && fs.existsSync(activity.imagePath)) {
      fs.unlinkSync(activity.imagePath);
    }

    activities.splice(activityIndex, 1);

    res.json({ message: 'Activity deleted successfully', id: req.params.id });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete activity' });
  }
});

// Search activities
app.get('/api/activities/search', (req, res) => {
  try {
    const { q } = req.query;

    if (!q) {
      return res.json(activities);
    }

    const searchQuery = q.toLowerCase();
    const filtered = activities.filter(activity => {
      const description = activity.description?.toLowerCase() || '';
      const location = `${activity.latitude},${activity.longitude}`;

      return description.includes(searchQuery) || location.includes(searchQuery);
    });

    res.json(filtered);
  } catch (error) {
    res.status(500).json({ error: 'Failed to search activities' });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: err.message || 'Something went wrong!' });
});

// Start server
app.listen(PORT, () => {
  console.log(`SmartTracker API server is running on port ${PORT}`);
  console.log(`API URL: http://localhost:${PORT}`);
  console.log(`Upload directory: ${path.join(__dirname, 'uploads')}`);
});

module.exports = app;
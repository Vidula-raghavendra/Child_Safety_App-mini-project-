import numpy as np
from sklearn.ensemble import RandomForestClassifier
import pickle
import os

def generate_dummy_data(samples=2000):
    """
    Generates synthetic gesture data.
    Features: [pressure (0-1), speed (px/s), duration (ms)]
    """
    # Child: Lighter pressure, faster/more erratic speed, shorter duration
    child_pressure = np.random.uniform(0.1, 0.5, samples // 2)
    child_speed = np.random.uniform(1000, 3000, samples // 2)
    child_duration = np.random.uniform(50, 250, samples // 2)
    child_data = np.column_stack((child_pressure, child_speed, child_duration))
    child_labels = np.zeros(samples // 2) # 0 for Child
    
    # Adult: Heavier pressure, steadier/slower speed, longer duration
    adult_pressure = np.random.uniform(0.5, 0.9, samples // 2)
    adult_speed = np.random.uniform(200, 1000, samples // 2)
    adult_duration = np.random.uniform(300, 800, samples // 2)
    adult_data = np.column_stack((adult_pressure, adult_speed, adult_duration))
    adult_labels = np.ones(samples // 2) # 1 for Adult
    
    X = np.vstack((child_data, adult_data))
    y = np.hstack((child_labels, adult_labels))
    
    # Shuffle
    indices = np.arange(X.shape[0])
    np.random.shuffle(indices)
    return X[indices], y[indices]

def train_model():
    print("Generating synthetic dataset...")
    X, y = generate_dummy_data()
    
    print("Training Random Forest Classifier...")
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X, y)
    
    # Save model
    with open('user_type_model.pkl', 'wb') as f:
        pickle.dump(model, f)
    print("Model trained and saved as 'user_type_model.pkl'")

def predict_user_type(pressure, speed, duration):
    if not os.path.exists('user_type_model.pkl'):
        train_model()
        
    with open('user_type_model.pkl', 'rb') as f:
        model = pickle.load(f)
    
    features = np.array([[pressure, speed, duration]])
    prediction = model.predict(features)
    
    return "Adult" if prediction[0] == 1 else "Child"

if __name__ == "__main__":
    # Example usage
    train_model()
    test_cases = [
        (0.2, 2500, 100), # Likely Child
        (0.8, 400, 600),  # Likely Adult
    ]
    
    for p, s, d in test_cases:
        result = predict_user_type(p, s, d)
        print(f"Input: Pressure={p}, Speed={s}, Duration={d}ms -> Predicted: {result}")

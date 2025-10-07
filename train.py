import os
import warnings

import mlflow
import mlflow.sklearn
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import  accuracy_score
from sklearn.model_selection import train_test_split

# Suppress unnecessary warnings for cleaner logs
warnings.filterwarnings("ignore")

def main():
    """Main function to run the training and logging process."""
    print("--- Starting the model training script ---")

    # --- MLflow Setup ---
    tracking_uri = os.environ.get("MLFLOW_TRACKING_URI")
    if tracking_uri:
        mlflow.set_tracking_uri(tracking_uri)
        print(f"MLflow tracking URI is set to: {tracking_uri}")
    else:
        print("MLflow tracking URI not found. Logging to local 'mlruns' directory.")

    experiment_name = "Iris-Classification-Experiment"
    mlflow.set_experiment(experiment_name)
    print(f"MLflow experiment has been set to: '{experiment_name}'")

    # --- Data Loading and Preparation ---
    print("Loading Iris dataset...")
    iris = load_iris()
    X, y = iris.data, iris.target
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    print("Dataset loaded and split.")

    # --- Model Training and Experiment Tracking ---
    with mlflow.start_run() as run:
        run_id = run.info.run_id
        print(f"MLflow Run ID: {run_id}")

        # Define and log model hyperparameters
        params = {"n_estimators": 100, "max_depth": 6, "random_state": 42}
        print(f"Logging parameters: {params}")
        mlflow.log_params(params)

        # Train the model
        print("Training RandomForestClassifier model...")
        model = RandomForestClassifier(**params)
        model.fit(X_train, y_train)
        print("Model training complete.")

        # Make predictions and log metrics
        predictions = model.predict(X_test)
        accuracy = accuracy_score(y_test, predictions)
        print(f"Model accuracy: {accuracy:.4f}")
        mlflow.log_metric("accuracy", accuracy)

        # Log the trained model as an artifact
        model_artifact_path = "iris-random-forest-model"
        print(f"Logging the model to artifact path: '{model_artifact_path}'...")
        mlflow.sklearn.log_model(model, model_artifact_path)
        print("Model successfully logged.")

        # --- NOWY KROK: Rejestracja modelu ---
        model_name = "IrisClassifier"
        model_uri = f"runs:/{run_id}/{model_artifact_path}"
        print(f"Registering model '{model_name}' from URI: {model_uri}")
        mlflow.register_model(model_uri=model_uri, name=model_name)
        print("Model successfully registered.")
        # ------------------------------------

        # Set a tag to identify the run context
        mlflow.set_tag("run_context", "jenkins_pipeline")
        print("Run tagged.")

    print("--- Training script finished successfully ---")

if __name__ == "__main__":
    main()
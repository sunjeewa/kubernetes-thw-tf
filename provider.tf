provider "google" {
  credentials = "${file("kubernetes-one-2f2eb99f0f85.json")}"
  project     = "kubernetes-one"
  region      = "us-central1"
  
}

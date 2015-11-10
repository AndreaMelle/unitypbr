using UnityEngine;
using System.Collections;

public class spin : MonoBehaviour {

	public float Speed = 1.0f;

	// Use this for initialization
	void Start () {
		Application.targetFrameRate = 60;
	}
	
	// Update is called once per frame
	void Update () {
		Vector3 r = transform.eulerAngles;
		r.y += Speed * Time.deltaTime;
		transform.eulerAngles = r;
	}
}

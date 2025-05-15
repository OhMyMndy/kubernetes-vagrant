def config
  {
    "control-plane-1": {
      "ip": "10.1.1.11",
      "memory": 2048,
      "groups": ["control_plane"],
    },
    "control-plane-2": {
      "ip": "10.1.1.12",
      "memory": 2048,
      "groups": ["control_plane"],
    },
    "worker-1": {
      "ip": "10.1.1.21",
      "node_labels": {
        "size": "small"
      },
      "groups": ["worker"],
    },
    "worker-2": {
      "ip": "10.1.1.22",
      "groups": ["worker"],
      "node_labels": {
        "size": "large"
      },
      "memory": 5200,
      "cpus": 3
    },
  }
end
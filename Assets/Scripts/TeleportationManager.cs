using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.Interaction.Toolkit;
using UnityEngine.InputSystem;

public class TeleportationManager : MonoBehaviour
{
    [SerializeField] private InputActionAsset actionasset;
    [SerializeField] private XRRayInteractor leftRay;
    [SerializeField] private XRRayInteractor rightRay;
    [SerializeField] private TeleportationProvider provider;
    private InputAction activateLeft;
    private InputAction activateRight;

    // Start is called before the first frame update
    void Start()
    {
        leftRay.enabled = false;
        activateLeft = actionasset.FindActionMap("XRI LeftHand").FindAction("Teleport Mode Activate", true);
        activateLeft.Enable();
        activateLeft.performed += OnTeleportActivate;
        activateLeft.canceled += OnTeleportCancle;

        rightRay.enabled = false;
        activateRight = actionasset.FindActionMap("XRI RightHand").FindAction("UI Mode Activate", true);
        activateRight.Enable();
        activateRight.performed += OnUIActivate;
        activateRight.canceled += OnUICancle;
    }

    void OnTeleportActivate(InputAction.CallbackContext context)
    {
        if (leftRay != null)
            leftRay.enabled = true;
    }

    void OnTeleportCancle(InputAction.CallbackContext context)
    {
        if (leftRay != null)
            leftRay.enabled = false;
    }

    void OnUIActivate(InputAction.CallbackContext context)
    {
        if (rightRay != null)
            rightRay.enabled = true;
    }

    void OnUICancle(InputAction.CallbackContext context)
    {
        if (rightRay != null)
            rightRay.enabled = false;
    }
}
